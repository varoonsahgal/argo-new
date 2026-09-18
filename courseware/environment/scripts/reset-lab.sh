#!/usr/bin/env bash
# reset-lab.sh — return the environment to a named checkpoint (blueprint 8.8).
#
#   reset-lab.sh <CP> [--yes] [--verify-only] [--local]
#   reset-lab.sh --list
#
# It is idempotent, works OFFLINE (Gitea, the vendored chart, seed mirrors, and
# checkpoint bundles are all local), targets under 3 minutes, and finishes by
# printing a PASS/FAIL table of the objects the checkpoint should contain.
#
#   --verify-only   print the PASS/FAIL table WITHOUT changing anything.
#   --yes           skip the "discards your work" confirmation.
#   --local         run against the build-machine sandbox.
#
# Reset algorithm (blueprint 8.8, in order):
#   1. revert any capstone faults (a disconnected cluster makes finalizers hang)
#   2. refresh CoreDNS host records
#   3. force-move main in every repo to cp-<name> from the local seed mirrors
#   4. delete non-checkpoint ApplicationSets, then Applications (cascade, root
#      before children, with a finalizer timeout); CP-baseline also recreates
#      hello-reconcile so Lab 1 starts at rollout revision 1 with one history entry
#   5. re-apply the checkpoint's declarative bundle (Secrets rendered from creds)
#   6. re-apply the workload-side RBAC state
#   7. clean or recreate workload namespaces
#   8. run apply-argocd-config pinned to THIS checkpoint's argocd/values.yaml
#      (so it restores a known-good configuration whatever state Git is in)
#   9. wait for expected statuses, then print verification
set -euo pipefail

# ---------------------------------------------------------------------------
# Argument parsing (extract --local before sourcing common).
# ---------------------------------------------------------------------------
COURSE_LOCAL=0
ASSUME_YES=0
VERIFY_ONLY=0
DO_LIST=0
CP_ARG=""
for arg in "$@"; do
  case "${arg}" in
    --local) COURSE_LOCAL=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    --verify-only) VERIFY_ONLY=1 ;;
    --list) DO_LIST=1 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "unknown flag: ${arg}" >&2; exit 2 ;;
    *) CP_ARG="${arg}" ;;
  esac
done
export COURSE_LOCAL

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

if [ "${DO_LIST}" -eq 1 ]; then
  step "Available checkpoints (blueprint 8.8)"
  for cp in ${CHECKPOINTS}; do printf '  %s\n' "${cp}"; done
  exit 0
fi

# CP-lab-01 is an accepted alias for CP-baseline.
[ "${CP_ARG}" = "CP-lab-01" ] && CP_ARG="CP-baseline"
[ -n "${CP_ARG}" ] || die "usage: reset-lab.sh <CP> [--yes] [--verify-only]  (see --list)"
case " ${CHECKPOINTS} " in
  *" ${CP_ARG} "*) : ;;
  *) die "unknown checkpoint: ${CP_ARG} (run reset-lab.sh --list)" ;;
esac

CP="${CP_ARG}"
IDX="$(checkpoint_index "${CP}")"
TAG="$(checkpoint_tag "${CP}")"
CAP_STATE="${COURSE_CAPSTONE_STATE}"

# ---------------------------------------------------------------------------
# Per-checkpoint plan. Sets the object sets the reset drives toward and verifies.
# ---------------------------------------------------------------------------
DES_APPS=""; DES_HEALTHY=""; DES_MANUAL=""; DES_APPSETS=""; DES_PROJECTS=""
WORKLOAD_REGISTERED=0; CAP_RBAC=0; EMPTY_NS=""

load_plan() {
  local lab05_apps="platform-root platform-quotas platform-netpol platform-agent \
storefront-dev-workload storefront-staging-workload storefront-prod-workload"
  case "${IDX}" in
    0|1) # CP-baseline / CP-lab-02
      DES_APPS="hello-reconcile"; DES_HEALTHY="hello-reconcile"
      EMPTY_NS="storefront-dev storefront-staging storefront-prod team-a platform-system"
      ;;
    2) # CP-lab-03
      DES_APPS="hello-reconcile storefront-dev"; DES_HEALTHY="hello-reconcile"
      DES_MANUAL="storefront-dev"; DES_PROJECTS="storefront"; WORKLOAD_REGISTERED=1
      EMPTY_NS="storefront-dev storefront-staging storefront-prod team-a platform-system"
      ;;
    3) # CP-lab-04 (Day 2 start): Day 1 Applications removed; nothing synced yet
      DES_PROJECTS="storefront platform"; WORKLOAD_REGISTERED=1
      EMPTY_NS="storefront-dev storefront-staging storefront-prod team-a platform-system"
      ;;
    4) # CP-lab-05
      DES_APPS="${lab05_apps}"; DES_HEALTHY="${lab05_apps}"; DES_APPSETS="storefront"
      DES_PROJECTS="storefront platform"; WORKLOAD_REGISTERED=1
      EMPTY_NS="team-a"
      ;;
    5|6) # CP-capstone / CP-capstone-restored
      DES_APPS="${lab05_apps} team-a-guestbook"; DES_HEALTHY="${lab05_apps} team-a-guestbook"
      DES_APPSETS="storefront"; DES_PROJECTS="storefront platform team-a"
      WORKLOAD_REGISTERED=1; CAP_RBAC=1
      ;;
    *) die "internal: unknown checkpoint index ${IDX}" ;;
  esac
}

# ---------------------------------------------------------------------------
# Small helpers.
# ---------------------------------------------------------------------------
in_list() { case " $2 " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
app_exists_kc() { kmgmt -n "${ARGOCD_NAMESPACE}" get application "$1" >/dev/null 2>&1; }
workload_token_present() {
  [ -n "$(kwork -n argocd-access get secret argocd-manager-token \
            -o jsonpath='{.data.token}' 2>/dev/null)" ]
}

argocd_login() {
  local pw; pw="$(read_cred "${COURSE_CRED_DIR}/argocd-admin.txt")"
  wait_for 120 "Argo CD API reachable on localhost:${ARGOCD_HOST_PORT}" \
    bash -c "curl -sk -o /dev/null 'https://localhost:${ARGOCD_HOST_PORT}/healthz'"
  argocd login "localhost:${ARGOCD_HOST_PORT}" --username admin \
    --password "${pw}" --insecure >/dev/null
}

# Apply Argo CD from THIS checkpoint's own argocd/values.yaml.
#
# apply-argocd-config.sh normally reads platform-config `main` from Gitea (the
# declarative source a participant edits). A reset must be independent of that:
# it pins the values to the checkpoint tree it just materialized, so the
# environment returns to a known-good configuration even if the repository has
# been left in any state at all. Step 3 has already force-moved `main` to the
# same tag, so Git and the cluster still agree afterwards.
reset_apply_argocd() {
  local pc="$1"
  local values="${pc}/argocd/values.yaml"
  [ -f "${values}" ] || die "checkpoint values missing: ${values}"
  ARGOCD_VALUES_FILE="${values}" bash "${COURSE_SCRIPTS_DIR}/apply-argocd-config.sh"
}

# Substitute <PLACEHOLDER> pairs in a template and apply to the mgmt cluster.
#
# Server-side apply, never client-side (E-3). A client-side `kubectl apply`
# stores a full copy of what it applied, password or token included, in the
# kubectl.kubernetes.io/last-applied-configuration annotation, where anything
# that can read Secret metadata (an ApplicationSet cluster generator, an error
# message) can leak it. Server-side apply never creates that annotation, but it
# keeps, and even rewrites, one that is already there (for example on a Secret a
# participant applied client-side), so strip any stale copy first.
render_and_apply_secret() {
  local template="$1"; shift
  [ -f "${template}" ] || die "secret template missing: ${template}"
  local content; content="$(cat "${template}")"
  while [ "$#" -ge 2 ]; do
    content="${content//$1/$2}"
    shift 2
  done
  local name ns
  name="$(yq '.metadata.name' "${template}")"
  ns="$(yq '.metadata.namespace // "argocd"' "${template}")"
  kmgmt -n "${ns}" annotate secret "${name}" \
    kubectl.kubernetes.io/last-applied-configuration- >/dev/null 2>&1 || true
  printf '%s\n' "${content}" | kmgmt apply --server-side --force-conflicts -f - >/dev/null
}

# Ensure the workload SA + token exist (idempotent); wait for the token.
ensure_workload_rbac() {
  local rbac="${COURSE_LABFILES_DIR}/lab-02/workload-rbac.yaml"
  [ -f "${rbac}" ] || rbac="${COURSE_ENV_DIR}/lab-files/lab-02/workload-rbac.yaml"
  kwork apply -f "${rbac}" >/dev/null
  wait_for 60 "argocd-manager-token populated" workload_token_present
}

# Force main of a repo to a checkpoint tag from the local seed mirror (offline).
force_main_to_checkpoint() {
  local repo="$1"
  local mirror="${COURSE_SEED_DIR}/${repo}.git"
  [ -d "${mirror}" ] || die "seed mirror missing: ${mirror} (run seed-repos.sh)"
  local pw; pw="$(read_cred "${COURSE_CRED_DIR}/gitea-student.txt")"
  local url="http://${GITEA_ADMIN_USER}:${pw}@localhost:${GITEA_HOST_PORT}/${GITEA_ORG}/${repo}.git"
  git --git-dir="${mirror}" push -q -f "${url}" "refs/tags/${TAG}:refs/heads/main" >/dev/null
  git --git-dir="${mirror}" push -q -f "${url}" --tags >/dev/null 2>&1 || true
}

# Cascade-delete an Application, waiting on its finalizer with a timeout.
delete_app_cascade() {
  local name="$1" timeout="${2:-90}"
  app_exists_kc "${name}" || return 0
  log "deleting Application ${name} (cascade)"
  kmgmt -n "${ARGOCD_NAMESPACE}" patch application "${name}" --type merge \
    -p '{"metadata":{"finalizers":["resources-finalizer.argocd.argoproj.io"]}}' >/dev/null 2>&1 || true
  kmgmt -n "${ARGOCD_NAMESPACE}" delete application "${name}" --wait=false >/dev/null 2>&1 || true
  local start; start="$(date +%s)"
  while app_exists_kc "${name}"; do
    if [ $(( $(date +%s) - start )) -ge "${timeout}" ]; then
      warn "finalizer timeout on ${name}; removing finalizer to force-delete"
      kmgmt -n "${ARGOCD_NAMESPACE}" patch application "${name}" --type merge \
        -p '{"metadata":{"finalizers":[]}}' >/dev/null 2>&1 || true
      kmgmt -n "${ARGOCD_NAMESPACE}" delete application "${name}" \
        --ignore-not-found --wait=false >/dev/null 2>&1 || true
      break
    fi
    sleep 2
  done
}

clean_workload_ns() {
  local ns="$1" kind
  kwork get ns "${ns}" >/dev/null 2>&1 || return 0
  # resourcequota/limitrange: the platform-quotas child writes them, and nothing
  # outside Argo CD creates them, so a leftover one belongs to a later lab.
  for kind in deployment statefulset daemonset replicaset service configmap job \
              horizontalpodautoscaler networkpolicy resourcequota limitrange pod; do
    kwork -n "${ns}" delete "${kind}" --all --ignore-not-found >/dev/null 2>&1 || true
  done
}

# ---------------------------------------------------------------------------
# The nine reset steps.
# ---------------------------------------------------------------------------
step1_revert_faults() {
  step "1/9 Revert any capstone faults"
  local markers=("${CAP_STATE}"/*.marker)
  if [ -e "${markers[0]}" ]; then
    local extra=()
    [ "${COURSE_LOCAL}" = "1" ] && extra+=(--local)
    bash "${COURSE_SCRIPTS_DIR}/inject-capstone-faults.sh" revert all "${extra[@]}"
  else
    ok "no fault markers present"
  fi
}

step2_refresh_coredns() {
  step "2/9 Refresh CoreDNS host records"
  bash "${COURSE_SCRIPTS_DIR}/lib/refresh-coredns-hosts.sh" "${MGMT_CONTEXT}" "${WORKLOAD_CONTEXT}"
}

step3_force_git() {
  step "3/9 Force every repo's main to ${TAG}"
  local repo
  for repo in ${COURSE_REPOS}; do
    force_main_to_checkpoint "${repo}"
    ok "${repo} main -> ${TAG}"
  done
  refresh_participant_clones
}

# A participant's own clones are working copies, so forcing `main` in Gitea does
# not touch the edits they already made. Without this, a reset leaves their
# previous answers (and half-finished experiments) sitting in the files the next
# lab tells them to edit. This is the "discards your work" the guides warn about.
refresh_participant_clones() {
  local dir name url
  # The clone URLs use the in-cluster host name `lab-gitea`, which only resolves
  # through the course git config's insteadOf rule. In --local mode HOME is the
  # build machine's, so that file has to be named explicitly.
  if [ -f "${COURSE_USER_HOME}/.gitconfig" ]; then
    export GIT_CONFIG_GLOBAL="${COURSE_USER_HOME}/.gitconfig"
  fi
  for dir in "${COURSE_USER_HOME}"/*/; do
    [ -d "${dir}.git" ] || continue
    # Only clones of the course's own repositories. COURSE_USER_HOME can be a
    # real home directory (argo-lab-env.sh sets it to $HOME), so an unrelated
    # project must never be hard-reset just because it also talks to port 3000.
    name="$(basename "${dir}")"
    in_list "${name}" "${COURSE_REPOS}" || continue
    # Match both spellings: the insteadOf rule above rewrites the lab-gitea host
    # to localhost, and `git remote get-url` prints the rewritten form.
    url="$(git -C "${dir}" remote get-url origin 2>/dev/null)" || continue
    case "${url}" in
      *"${GITEA_CONTAINER}:${GITEA_HOST_PORT}/${GITEA_ORG}/${name}"*) ;;
      *"localhost:${GITEA_HOST_PORT}/${GITEA_ORG}/${name}"*) ;;
      *) continue ;;
    esac
    if git -C "${dir}" fetch --quiet origin 2>/dev/null \
       && git -C "${dir}" reset --hard --quiet origin/main 2>/dev/null \
       && git -C "${dir}" clean -qfd 2>/dev/null; then
      ok "clone ${name} reset to origin/main"
    else
      warn "could not reset clone ${name}; leaving it untouched"
    fi
  done
}

step4_delete_nondesired() {
  step "4/9 Delete non-checkpoint ApplicationSets, then Applications"
  local name
  for name in $(kmgmt -n "${ARGOCD_NAMESPACE}" get applicationset \
                  -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
    in_list "${name}" "${DES_APPSETS}" && continue
    log "deleting ApplicationSet ${name}"
    kmgmt -n "${ARGOCD_NAMESPACE}" delete applicationset "${name}" --ignore-not-found >/dev/null 2>&1 || true
  done
  # Roots before children.
  for name in platform-root team-root; do
    in_list "${name}" "${DES_APPS}" && continue
    delete_app_cascade "${name}"
  done
  for name in $(kmgmt -n "${ARGOCD_NAMESPACE}" get application \
                  -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
    in_list "${name}" "${DES_APPS}" && continue
    delete_app_cascade "${name}"
  done
  # CP-baseline is Lab 1's start, and Lab 1 uses the Deployment's rollout history
  # ("one revision: no new Pod started") and the sync history as evidence. Forcing
  # Git back is not enough: a rehearsal's ReplicaSets and history entries survive
  # a plain re-sync. Recreate hello-reconcile from scratch, as bootstrap does;
  # step 5 re-applies it and step 9 syncs it (rollout revision 1, one entry).
  if [ "${IDX}" -eq 0 ]; then
    delete_app_cascade hello-reconcile
    wait_for 90 "hello-reconcile workload removed" hello_workload_gone || true
  fi
  # Projects a participant created in a later lab (team-a in Lab 5) belong to
  # that lab, not to an earlier checkpoint. `default` is built in and stays.
  for name in $(kmgmt -n "${ARGOCD_NAMESPACE}" get appproject \
                  -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
    [ "${name}" = "default" ] && continue
    in_list "${name}" "${DES_PROJECTS}" && continue
    log "deleting AppProject ${name}"
    kmgmt -n "${ARGOCD_NAMESPACE}" delete appproject "${name}" \
      --ignore-not-found >/dev/null 2>&1 || true
  done
  # Onboarding Secrets (repository / repo-creds / cluster) that a later lab
  # created, plus Lab 2's deliberately broken ones. Without this, resetting back
  # to CP-lab-02 leaves storefront-gitops connected and the workload cluster
  # registered with a dead token: the exact things Lab 2 asks participants to
  # build. Applications are already gone, so no finalizer depends on them.
  for name in $(kmgmt -n "${ARGOCD_NAMESPACE}" get secret \
                  -l 'argocd.argoproj.io/secret-type in (repository,repo-creds,cluster)' \
                  -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
    in_list "${name}" "$(expected_onboarding_secrets)" && continue
    log "deleting onboarding Secret ${name}"
    kmgmt -n "${ARGOCD_NAMESPACE}" delete secret "${name}" \
      --ignore-not-found >/dev/null 2>&1 || true
  done
  ok "non-checkpoint AppSets/Applications/AppProjects/onboarding Secrets removed"
}

# The repository, repo-creds, and cluster Secrets a checkpoint should contain.
expected_onboarding_secrets() {
  local keep="in-cluster"
  [ "${IDX}" -ge 2 ] && keep="${keep} repo-storefront-gitops"
  [ "${WORKLOAD_REGISTERED}" -eq 1 ] && keep="${keep} cluster-workload"
  [ "${IDX}" -ge 3 ] && keep="${keep} course-repo-creds"
  printf '%s' "${keep}"
}

step5_apply_bundle() {
  step "5/9 Apply the checkpoint declarative bundle"
  local pc="${1}" hello="${2}"
  local gitea_pw; gitea_pw="$(read_cred "${COURSE_CRED_DIR}/gitea-student.txt")"

  # Cluster registration Secret for the management cluster (labels only).
  kmgmt apply -f "${pc}/clusters/in-cluster.secret.yaml" >/dev/null
  ok "in-cluster Secret applied"

  # Projects.
  local proj
  for proj in ${DES_PROJECTS}; do
    kmgmt apply -f "${pc}/projects/${proj}.yaml" >/dev/null
    ok "AppProject ${proj} applied"
  done

  # Repository / repo-creds Secrets (rendered from the Gitea credential).
  if [ "${IDX}" -ge 2 ]; then
    render_and_apply_secret "${pc}/repositories/storefront-gitops.secret.template.yaml" \
      "<PASSWORD>" "${gitea_pw}"
    ok "repository Secret repo-storefront-gitops applied"
  fi
  if [ "${IDX}" -ge 3 ]; then
    render_and_apply_secret "${pc}/repositories/course-repo-creds.secret.template.yaml" \
      "<PASSWORD>" "${gitea_pw}"
    ok "repo-creds Secret course-repo-creds applied"
  fi

  # Workload cluster registration Secret (needs a live SA token + CA).
  if [ "${WORKLOAD_REGISTERED}" -eq 1 ]; then
    ensure_workload_rbac
    local token ca
    token="$(kwork -n argocd-access get secret argocd-manager-token \
      -o go-template='{{ index .data "token" | base64decode }}')"
    ca="$(kwork -n argocd-access get secret argocd-manager-token -o jsonpath='{.data.ca\.crt}')"
    render_and_apply_secret "${pc}/clusters/workload.secret.template.yaml" \
      "<TOKEN>" "${token}" "<CA_DATA>" "${ca}"
    ok "cluster Secret cluster-workload applied"
  fi

  # Applications and ApplicationSets.
  if in_list "hello-reconcile" "${DES_APPS}"; then
    kmgmt apply -f "${hello}/argocd/hello-reconcile-app.yaml" >/dev/null
    ok "Application hello-reconcile applied"
  fi
  if in_list "storefront-dev" "${DES_APPS}"; then
    kmgmt apply -f "${pc}/applications/storefront-dev.yaml" >/dev/null
    ok "Application storefront-dev applied (manual)"
  fi
  if in_list "storefront" "${DES_APPSETS}"; then
    kmgmt apply -f "${pc}/applicationsets/storefront.yaml" >/dev/null
    ok "ApplicationSet storefront applied"
  fi
  if in_list "platform-root" "${DES_APPS}"; then
    kmgmt apply -f "${pc}/root/platform-root.yaml" >/dev/null
    ok "Application platform-root applied (App-of-Apps)"
  fi
  if in_list "team-a-guestbook" "${DES_APPS}"; then
    kmgmt apply -f "${pc}/applications/team-a-guestbook.yaml" >/dev/null
    ok "Application team-a-guestbook applied"
  fi
}

step6_workload_rbac() {
  step "6/9 Reconcile workload-side RBAC"
  local rbac="${COURSE_LABFILES_DIR}/lab-02/workload-rbac.yaml"
  [ -f "${rbac}" ] || rbac="${COURSE_ENV_DIR}/lab-files/lab-02/workload-rbac.yaml"
  if [ "${WORKLOAD_REGISTERED}" -eq 1 ]; then
    kwork apply -f "${rbac}" >/dev/null
    ok "least-privilege RBAC applied on workload cluster"
  else
    kwork delete -f "${rbac}" --ignore-not-found >/dev/null 2>&1 || true
    ok "workload RBAC removed (baseline: not registered)"
  fi
  # `argocd cluster add` (Lab 2 stretch A) creates these on the workload cluster
  # BEFORE it fails: a ServiceAccount in kube-system, a ClusterRole granting every
  # verb on every resource, its binding, and a long-lived token. No checkpoint
  # uses them, and they silently undo least privilege, so always remove them.
  kwork delete clusterrolebinding argocd-manager-role-binding --ignore-not-found >/dev/null 2>&1 || true
  kwork delete clusterrole argocd-manager-role --ignore-not-found >/dev/null 2>&1 || true
  kwork -n kube-system delete secret argocd-manager-long-lived-token --ignore-not-found >/dev/null 2>&1 || true
  kwork -n kube-system delete serviceaccount argocd-manager --ignore-not-found >/dev/null 2>&1 || true
  ok "no cluster-wide argocd-manager leftovers (from argocd cluster add) on workload"
}

step7_workload_ns() {
  step "7/9 Clean/recreate workload namespaces"
  local ns
  for ns in argocd-access storefront-dev storefront-staging storefront-prod team-a platform-system; do
    kwork get ns "${ns}" >/dev/null 2>&1 || kwork create ns "${ns}" >/dev/null
  done
  for ns in ${EMPTY_NS}; do
    clean_workload_ns "${ns}"
  done
  ok "workload namespaces present; empty-checkpoint namespaces cleaned"
}

step8_apply_argocd() {
  local pc="$1"
  step "8/9 Apply Argo CD configuration"
  ensure_dir "${COURSE_STATE_DIR}"
  # Every checkpoint's Argo CD configuration now lives in that checkpoint's own
  # platform-config/argocd/values.yaml (cp-capstone's copy carries the Lab 5
  # role:team-a policy). No side-car overlay files are needed any more; clear the
  # list so a stale one from an older run can never leak into a fault repair.
  : > "${COURSE_STATE_DIR}/argocd-overlays.list"
  rm -f "${COURSE_STATE_DIR}/capstone-rbac.values.yaml"
  reset_apply_argocd "${pc}"
}

step9_wait_and_verify() {
  step "9/9 Wait for expected statuses"
  argocd_login
  local name
  # Manual apps: ensure Synced/Healthy where the checkpoint expects it (hello).
  if in_list "hello-reconcile" "${DES_HEALTHY}"; then
    argocd app sync hello-reconcile --timeout 180 >/dev/null 2>&1 || true
    argocd app wait hello-reconcile --health --sync --timeout 180 >/dev/null 2>&1 || true
  fi
  # Automated apps (children + AppSet-generated): wait for creation, then settle.
  for name in ${DES_HEALTHY}; do
    [ "${name}" = "hello-reconcile" ] && continue
    wait_for 120 "Application ${name} created" app_exists_kc "${name}"
    argocd app sync "${name}" --timeout 180 >/dev/null 2>&1 || true
    argocd app wait "${name}" --health --sync --timeout 180 >/dev/null 2>&1 || true
  done
  ok "expected applications settled"
}

# ---------------------------------------------------------------------------
# Verification (mutation-free). Used by --verify-only and step 9.
# ---------------------------------------------------------------------------
VERIFY_FAILS=0
vrow() {
  local label="$1" result="$2"
  if [ "${result}" = "PASS" ]; then
    printf '  %sPASS%s  %s\n' "${_c_green}" "${_c_reset}" "${label}"
  else
    printf '  %sFAIL%s  %s\n' "${_c_red}" "${_c_reset}" "${label}"
    VERIFY_FAILS=$((VERIFY_FAILS + 1))
  fi
}
bool_pass() { if "$@" >/dev/null 2>&1; then echo PASS; else echo FAIL; fi; }
bool_fail() { if "$@" >/dev/null 2>&1; then echo FAIL; else echo PASS; fi; }

only_expected_onboarding_secrets() {
  local name
  for name in $(kmgmt -n "${ARGOCD_NAMESPACE}" get secret \
                  -l 'argocd.argoproj.io/secret-type in (repository,repo-creds,cluster)' \
                  -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
    in_list "${name}" "$(expected_onboarding_secrets)" || return 1
  done
}

hello_workload_gone() {
  [ -z "$(kmgmt -n hello get deployment,replicaset \
            -l app.kubernetes.io/name=hello-reconcile -o name 2>/dev/null)" ]
}

# Lab 1's starting Deployment: first rollout, and no Pod-template annotations
# (Lab 1 has participants add the checksum/config annotation themselves).
hello_fresh_rollout() {
  local rev ann
  rev="$(kmgmt -n hello get deployment hello-reconcile \
    -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}' 2>/dev/null)"
  ann="$(kmgmt -n hello get deployment hello-reconcile \
    -o jsonpath='{.spec.template.metadata.annotations}' 2>/dev/null)"
  [ "${rev}" = "1" ] && [ -z "${ann}" ]
}

app_healthy_synced() {
  local h s
  h="$(kmgmt -n "${ARGOCD_NAMESPACE}" get application "$1" -o jsonpath='{.status.health.status}' 2>/dev/null)"
  s="$(kmgmt -n "${ARGOCD_NAMESPACE}" get application "$1" -o jsonpath='{.status.sync.status}' 2>/dev/null)"
  [ "${h}" = "Healthy" ] && [ "${s}" = "Synced" ]
}

verify_checkpoint() {
  step "Verification for ${CP}"
  VERIFY_FAILS=0
  local name

  # Applications that must exist (and be Synced/Healthy when expected).
  for name in ${DES_APPS}; do
    if in_list "${name}" "${DES_MANUAL}"; then
      vrow "Application ${name} present (manual)" "$(bool_pass app_exists_kc "${name}")"
    elif in_list "${name}" "${DES_HEALTHY}"; then
      vrow "Application ${name} Synced/Healthy" "$(bool_pass app_healthy_synced "${name}")"
    else
      vrow "Application ${name} present" "$(bool_pass app_exists_kc "${name}")"
    fi
  done

  if [ "${IDX}" -eq 0 ]; then
    vrow "Deployment hello-reconcile at rollout revision 1, no Pod-template annotations" \
      "$(bool_pass hello_fresh_rollout)"
  fi

  # Day 1 Applications that must be GONE from Day 2 onward.
  if [ "${IDX}" -ge 3 ]; then
    vrow "Application hello-reconcile absent" "$(bool_fail app_exists_kc hello-reconcile)"
    vrow "Application storefront-dev absent" "$(bool_fail app_exists_kc storefront-dev)"
  fi

  # Lab 5 builds team-a. Before the capstone checkpoint it must not exist, or a
  # participant repeating Lab 5 would start from their own previous answer.
  if [ "${IDX}" -le 4 ]; then
    vrow "Application team-a-guestbook absent" "$(bool_fail app_exists_kc team-a-guestbook)"
    vrow "AppProject team-a absent" \
      "$(bool_fail kmgmt -n "${ARGOCD_NAMESPACE}" get appproject team-a)"
  fi

  # ApplicationSets.
  for name in ${DES_APPSETS}; do
    vrow "ApplicationSet ${name} present" \
      "$(bool_pass kmgmt -n "${ARGOCD_NAMESPACE}" get applicationset "${name}")"
  done

  # Projects.
  for name in ${DES_PROJECTS}; do
    vrow "AppProject ${name} present" \
      "$(bool_pass kmgmt -n "${ARGOCD_NAMESPACE}" get appproject "${name}")"
  done

  # Secrets.
  vrow "Secret in-cluster present" \
    "$(bool_pass kmgmt -n "${ARGOCD_NAMESPACE}" get secret in-cluster)"
  if [ "${IDX}" -ge 2 ]; then
    vrow "Secret repo-storefront-gitops present" \
      "$(bool_pass kmgmt -n "${ARGOCD_NAMESPACE}" get secret repo-storefront-gitops)"
    vrow "Secret cluster-workload present" \
      "$(bool_pass kmgmt -n "${ARGOCD_NAMESPACE}" get secret cluster-workload)"
  fi
  if [ "${IDX}" -ge 3 ]; then
    vrow "Secret course-repo-creds present" \
      "$(bool_pass kmgmt -n "${ARGOCD_NAMESPACE}" get secret course-repo-creds)"
  fi
  local want; want="$(expected_onboarding_secrets)"
  vrow "Repository and cluster Secrets are exactly: ${want// /, }" \
    "$(bool_pass only_expected_onboarding_secrets)"

  # Workload namespaces + RBAC.
  vrow "workload namespace storefront-prod present" \
    "$(bool_pass kwork get ns storefront-prod)"
  if [ "${WORKLOAD_REGISTERED}" -eq 1 ]; then
    vrow "workload SA argocd-manager present" \
      "$(bool_pass kwork -n argocd-access get serviceaccount argocd-manager)"
    vrow "workload RoleBinding argocd-deployer (storefront-prod) present" \
      "$(bool_pass kwork -n storefront-prod get rolebinding argocd-deployer)"
  else
    vrow "workload SA argocd-manager absent (not registered)" \
      "$(bool_fail kwork -n argocd-access get serviceaccount argocd-manager)"
  fi

  # Capstone Argo CD RBAC.
  if [ "${CAP_RBAC}" -eq 1 ]; then
    local csv
    csv="$(kmgmt -n "${ARGOCD_NAMESPACE}" get configmap argocd-rbac-cm \
      -o jsonpath='{.data.policy\.csv}' 2>/dev/null)"
    if printf '%s' "${csv}" | grep -q 'role:team-a'; then
      vrow "Argo CD RBAC role:team-a -> team-a-dev present" PASS
    else
      vrow "Argo CD RBAC role:team-a -> team-a-dev present" FAIL
    fi
  fi

  echo
  if [ "${VERIFY_FAILS}" -eq 0 ]; then
    printf '%s%sPASS%s %s is in the expected state.\n' "${_c_bold}" "${_c_green}" "${_c_reset}" "${CP}"
    return 0
  fi
  printf '%s%sFAIL%s %d check(s) failed for %s.\n' "${_c_bold}" "${_c_red}" "${_c_reset}" \
    "${VERIFY_FAILS}" "${CP}"
  return 1
}

confirm() {
  [ "${ASSUME_YES}" -eq 1 ] && return 0
  if [ -t 0 ]; then
    printf '%sThis resets the environment to %s and DISCARDS your current work.%s\n' \
      "${_c_yellow}" "${CP}" "${_c_reset}"
    printf 'Type the checkpoint name to confirm: '
    local ans; read -r ans
    [ "${ans}" = "${CP}" ] || die "confirmation did not match; aborting"
  else
    warn "non-interactive shell: proceeding without confirmation (${CP})"
  fi
}

main() {
  require_cmd docker kubectl helm argocd git yq curl
  load_plan

  if [ "${VERIFY_ONLY}" -eq 1 ]; then
    verify_checkpoint
    exit $?
  fi

  confirm

  local pc hello
  pc="$(mktemp -d)"; hello="$(mktemp -d)"
  materialize_repo platform-config "${CP}" "${pc}"
  materialize_repo hello-reconcile "${CP}" "${hello}"

  step1_revert_faults
  step2_refresh_coredns
  step3_force_git
  step4_delete_nondesired
  step5_apply_bundle "${pc}" "${hello}"
  step6_workload_rbac
  step7_workload_ns
  step8_apply_argocd "${pc}"
  step9_wait_and_verify

  rm -rf "${pc}" "${hello}"

  verify_checkpoint
}

main
