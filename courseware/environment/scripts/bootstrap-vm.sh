#!/usr/bin/env bash
# bootstrap-vm.sh — provision one course VM (or the local build-machine sandbox)
# from nothing to CP-baseline (blueprint sections 8.3, 8.12). Idempotent.
#
#   --local     run on the build machine (macOS/Linux, no sudo): tools go to
#               $COURSE_TOOLS_DIR, everything under $HOME/.argocd-course.
#   --rebuild   delete and recreate both k3d clusters and Gitea data, then
#               reprovision. Last resort; also works offline from vendored assets.
#   --commands-only
#               install ONLY the course commands (reset-lab.sh, capstone-check,
#               ...) onto PATH and exit. Cheap repair when a VM has the clusters
#               but a lab guide reports "command not found".
#
# Order: pinned tools -> course commands on PATH -> vendored chart + image
# tarballs -> Docker network -> k3d mgmt + workload clusters -> Gitea + users ->
# seed repos -> Argo CD -> in-cluster Secret + workload namespaces ->
# hello-reconcile Synced/Healthy -> CP-baseline smoke test.
set -euo pipefail

# ---- parse args (before sourcing common, which reads COURSE_LOCAL) ----
COURSE_LOCAL=0
REBUILD=0
COMMANDS_ONLY=0
for arg in "$@"; do
  case "${arg}" in
    --local) COURSE_LOCAL=1 ;;
    --rebuild) REBUILD=1 ;;
    --commands-only) COMMANDS_ONLY=1 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: ${arg}" >&2; exit 2 ;;
  esac
done
export COURSE_LOCAL

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# ---------------------------------------------------------------------------
# Platform detection for tool downloads.
# ---------------------------------------------------------------------------
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"   # darwin | linux
ARCH_RAW="$(uname -m)"
case "${ARCH_RAW}" in
  x86_64|amd64) ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *) die "unsupported architecture: ${ARCH_RAW}" ;;
esac

# ---------------------------------------------------------------------------
# Pinned tool installation (idempotent; skips when the right version is present).
# ---------------------------------------------------------------------------
install_tools() {
  step "Installing pinned tools into ${COURSE_TOOLS_DIR}"
  ensure_dir "${COURSE_TOOLS_DIR}"
  local tmp; tmp="$(mktemp -d)"

  if ! "${COURSE_TOOLS_DIR}/kubectl" version --client 2>/dev/null | grep -q "${KUBECTL_VERSION}"; then
    log "downloading kubectl ${KUBECTL_VERSION}"
    curl -fsSL -o "${tmp}/kubectl" \
      "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl"
    install -m 0755 "${tmp}/kubectl" "${COURSE_TOOLS_DIR}/kubectl"
  fi
  ok "kubectl $("${COURSE_TOOLS_DIR}/kubectl" version --client 2>/dev/null | head -1)"

  if ! "${COURSE_TOOLS_DIR}/helm" version --short 2>/dev/null | grep -q "${HELM_VERSION}"; then
    log "downloading helm ${HELM_VERSION}"
    curl -fsSL -o "${tmp}/helm.tgz" \
      "https://get.helm.sh/helm-${HELM_VERSION}-${OS}-${ARCH}.tar.gz"
    tar -xzf "${tmp}/helm.tgz" -C "${tmp}"
    install -m 0755 "${tmp}/${OS}-${ARCH}/helm" "${COURSE_TOOLS_DIR}/helm"
  fi
  ok "helm $("${COURSE_TOOLS_DIR}/helm" version --short 2>/dev/null)"

  if ! "${COURSE_TOOLS_DIR}/argocd" version --client 2>/dev/null | grep -q "${ARGOCD_CLI_VERSION}"; then
    log "downloading argocd ${ARGOCD_CLI_VERSION}"
    curl -fsSL -o "${tmp}/argocd" \
      "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_CLI_VERSION}/argocd-${OS}-${ARCH}"
    install -m 0755 "${tmp}/argocd" "${COURSE_TOOLS_DIR}/argocd"
  fi
  ok "argocd $("${COURSE_TOOLS_DIR}/argocd" version --client 2>/dev/null | head -1)"

  if ! "${COURSE_TOOLS_DIR}/yq" --version 2>/dev/null | grep -q "${YQ_VERSION}"; then
    log "downloading yq ${YQ_VERSION}"
    curl -fsSL -o "${tmp}/yq" \
      "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_${OS}_${ARCH}"
    install -m 0755 "${tmp}/yq" "${COURSE_TOOLS_DIR}/yq"
  fi
  ok "yq $("${COURSE_TOOLS_DIR}/yq" --version 2>/dev/null)"

  command -v k3d >/dev/null 2>&1 || die "k3d not installed (install k3d ${K3D_MIN_VERSION}: https://k3d.io)"
  ok "k3d $(k3d version | head -1)"
  rm -rf "${tmp}"
}

# ---------------------------------------------------------------------------
# Course commands on PATH.
#
# Every lab guide calls `reset-lab.sh`, `apply-argocd-config.sh`,
# `capstone-check` and `inject-capstone-faults.sh` as bare commands. The scripts
# themselves live in the course payload checkout, which is NOT on anyone's PATH,
# so they are published here as tiny wrapper scripts into two directories:
#
#   ${COURSE_HOME}/bin    the documented home of the course commands
#                         (/opt/course/bin on a VM; blueprint 8.12)
#   ${COURSE_TOOLS_DIR}   where the pinned kubectl/helm/argocd already live, and
#                         therefore already on PATH (/usr/local/bin on a VM)
#
# Wrappers, not symlinks: each script resolves its own directory to source
# lib/common.sh, and a symlink would make that resolve to the link's directory.
# ---------------------------------------------------------------------------
COURSE_COMMANDS="reset-lab.sh apply-argocd-config.sh inject-capstone-faults.sh \
capstone-check.sh seed-repos.sh bootstrap-vm.sh"

# Write one wrapper. Uses sudo only on a VM, only when the target directory is
# not writable, and only if sudo needs no password (cloud-init grants that).
write_wrapper() {
  local dest="$1" target="$2" dir tmp
  dir="$(dirname "${dest}")"
  tmp="$(mktemp)"
  {
    printf '#!/usr/bin/env bash\n'
    printf '# Course command wrapper, generated by bootstrap-vm.sh. Do not edit.\n'
    printf '# Runs the real script from the course payload so its lib/ files resolve.\n'
    printf 'exec "%s" "$@"\n' "${target}"
  } > "${tmp}"
  if [ -d "${dir}" ] && [ -w "${dir}" ]; then
    install -m 0755 "${tmp}" "${dest}"
  elif [ "${COURSE_LOCAL}" != "1" ] && sudo -n true >/dev/null 2>&1; then
    sudo install -D -m 0755 "${tmp}" "${dest}"
  else
    rm -f "${tmp}"
    return 1
  fi
  rm -f "${tmp}"
}

install_course_commands() {
  step "Installing course commands onto PATH"
  local bindir="${COURSE_HOME}/bin" cmd failed=0
  mkdir -p "${bindir}" 2>/dev/null || true
  for cmd in ${COURSE_COMMANDS}; do
    [ -f "${COURSE_SCRIPTS_DIR}/${cmd}" ] || { warn "no such course script: ${cmd}"; continue; }
    write_wrapper "${bindir}/${cmd}" "${COURSE_SCRIPTS_DIR}/${cmd}" || failed=1
    # Same wrapper in the pinned-tools directory, which is already on PATH.
    if [ "${COURSE_TOOLS_DIR}" != "${bindir}" ]; then
      write_wrapper "${COURSE_TOOLS_DIR}/${cmd}" "${COURSE_SCRIPTS_DIR}/${cmd}" || failed=1
    fi
  done
  # Blueprint 8.9 names the companion `capstone-check` (no extension); publish
  # both spellings so either one a guide uses works.
  write_wrapper "${bindir}/capstone-check" "${COURSE_SCRIPTS_DIR}/capstone-check.sh" || failed=1
  if [ "${COURSE_TOOLS_DIR}" != "${bindir}" ]; then
    write_wrapper "${COURSE_TOOLS_DIR}/capstone-check" "${COURSE_SCRIPTS_DIR}/capstone-check.sh" || failed=1
  fi

  # VM only: a login-shell PATH entry for ${COURSE_HOME}/bin. cloud-init normally
  # writes this already; doing it here too makes a hand-built VM behave the same.
  if [ "${COURSE_LOCAL}" != "1" ] && [ ! -f /etc/profile.d/course-path.sh ]; then
    local tmp; tmp="$(mktemp)"
    printf '# Course commands (generated by bootstrap-vm.sh).\nexport PATH="%s:$PATH"\n' \
      "${bindir}" > "${tmp}"
    if sudo -n true >/dev/null 2>&1; then
      sudo install -m 0644 "${tmp}" /etc/profile.d/course-path.sh
      ok "PATH entry written to /etc/profile.d/course-path.sh"
    else
      warn "could not write /etc/profile.d/course-path.sh (no passwordless sudo);"
      warn "add ${bindir} to PATH by hand if a course command is not found"
    fi
    rm -f "${tmp}"
  fi

  if [ "${failed}" -eq 0 ]; then
    ok "course commands installed in ${bindir} and ${COURSE_TOOLS_DIR}"
  else
    warn "some course commands could not be installed (permissions); see above"
  fi
  # Prove at least one is reachable from this shell.
  if command -v reset-lab.sh >/dev/null 2>&1; then
    ok "reset-lab.sh resolves to $(command -v reset-lab.sh)"
  else
    warn "reset-lab.sh is not on PATH in this shell (open a new login shell)"
  fi
}

# ---------------------------------------------------------------------------
# Vendored chart + image tarballs for offline resets/rebuilds.
# ---------------------------------------------------------------------------
vendor_assets() {
  step "Vendoring chart and images into ${COURSE_HOME}"
  ensure_dir "${COURSE_CHART_DIR}"; ensure_dir "${COURSE_IMAGE_DIR}"
  if [ ! -f "${COURSE_CHART_PATH}" ]; then
    log "downloading Argo CD chart ${ARGOCD_CHART_VERSION}"
    curl -fsSL -o "${COURSE_CHART_PATH}" "${ARGOCD_CHART_URL}"
  fi
  ok "chart at ${COURSE_CHART_PATH}"

  # Read the exact Argo CD image the chart pins, so the tarball matches.
  local argocd_img="quay.io/argoproj/argocd:${ARGOCD_VERSION}"
  local images=(
    "${argocd_img}"
    "${REDIS_IMAGE_REPO}:${REDIS_IMAGE_TAG}"
    "${PODINFO_IMAGE}"
    "${PODINFO_PREV_IMAGE}"
    "${BUSYBOX_IMAGE}"
    "${GITEA_IMAGE}"
  )
  local img
  for img in "${images[@]}"; do
    if ! docker image inspect "${img}" >/dev/null 2>&1; then
      log "pulling ${img}"
      docker pull -q "${img}" >/dev/null || warn "could not pull ${img} (will rely on in-cluster pull)"
    fi
  done
  ok "base images present in local Docker"
}

import_one() {
  local img="$1" cluster="$2"
  if docker image inspect "${img}" >/dev/null 2>&1; then
    k3d image import "${img}" -c "${cluster}" >/dev/null 2>&1 || warn "import ${img} -> ${cluster} failed"
  else
    warn "image ${img} not in local Docker; skipping import to ${cluster}"
  fi
}

import_images() {
  # Load host images into each cluster's containerd so pods start without pulls.
  local img
  step "Importing images into clusters"
  for img in "quay.io/argoproj/argocd:${ARGOCD_VERSION}" "${REDIS_IMAGE_REPO}:${REDIS_IMAGE_TAG}" "${PODINFO_IMAGE}"; do
    import_one "${img}" "${MGMT_CLUSTER}"
  done
  # PODINFO_PREV_IMAGE: storefront dev/staging start on it on Day 1 (Lab 3 E2
  # promotes it to PODINFO_IMAGE).
  for img in "${PODINFO_IMAGE}" "${PODINFO_PREV_IMAGE}" "${BUSYBOX_IMAGE}"; do
    import_one "${img}" "${WORKLOAD_CLUSTER}"
  done
  ok "image import complete"
}

# ---------------------------------------------------------------------------
# Docker network + k3d clusters.
# ---------------------------------------------------------------------------
ensure_network() {
  step "Ensuring Docker network ${DOCKER_NETWORK}"
  docker network inspect "${DOCKER_NETWORK}" >/dev/null 2>&1 || \
    docker network create "${DOCKER_NETWORK}" >/dev/null
  ok "network ${DOCKER_NETWORK} present"
}

ensure_cluster_mgmt() {
  step "Ensuring k3d cluster '${MGMT_CLUSTER}'"
  if k3d cluster list "${MGMT_CLUSTER}" >/dev/null 2>&1; then
    if [ "${REBUILD}" -eq 1 ]; then
      log "rebuild: deleting cluster ${MGMT_CLUSTER}"
      k3d cluster delete "${MGMT_CLUSTER}" >/dev/null
    else
      ok "cluster ${MGMT_CLUSTER} already exists"
      return 0
    fi
  fi
  k3d cluster create "${MGMT_CLUSTER}" \
    --image "${K3S_IMAGE}" \
    --network "${DOCKER_NETWORK}" \
    --api-port "127.0.0.1:${MGMT_API_PORT}" \
    --port "${ARGOCD_HOST_PORT}:${ARGOCD_NODEPORT}@server:0:direct" \
    --no-lb \
    --k3s-arg "--disable=traefik@server:0" \
    --k3s-arg "--disable=servicelb@server:0" \
    --wait
  ok "cluster ${MGMT_CLUSTER} created (context ${MGMT_CONTEXT})"
}

ensure_cluster_workload() {
  step "Ensuring k3d cluster '${WORKLOAD_CLUSTER}'"
  if k3d cluster list "${WORKLOAD_CLUSTER}" >/dev/null 2>&1; then
    if [ "${REBUILD}" -eq 1 ]; then
      log "rebuild: deleting cluster ${WORKLOAD_CLUSTER}"
      k3d cluster delete "${WORKLOAD_CLUSTER}" >/dev/null
    else
      ok "cluster ${WORKLOAD_CLUSTER} already exists"
      return 0
    fi
  fi
  k3d cluster create "${WORKLOAD_CLUSTER}" \
    --image "${K3S_IMAGE}" \
    --network "${DOCKER_NETWORK}" \
    --api-port "127.0.0.1:${WORKLOAD_API_PORT}" \
    --no-lb \
    --k3s-arg "--disable=traefik@server:0" \
    --k3s-arg "--disable=servicelb@server:0" \
    --k3s-arg "--tls-san=${WORKLOAD_NODE}@server:0" \
    --wait
  ok "cluster ${WORKLOAD_CLUSTER} created (context ${WORKLOAD_CONTEXT})"
}

# ---------------------------------------------------------------------------
# Credentials (generated once; reused on re-runs).
# ---------------------------------------------------------------------------
gen_cred() {
  local file="$1"
  if [ ! -f "${file}" ]; then
    ensure_dir "$(dirname "${file}")"
    ( umask 077; openssl rand -hex 16 > "${file}" )
    chmod 600 "${file}"
  fi
}

ensure_credentials() {
  step "Ensuring per-VM credentials in ${COURSE_CRED_DIR}"
  ensure_dir "${COURSE_CRED_DIR}"; chmod 700 "${COURSE_CRED_DIR}" 2>/dev/null || true
  gen_cred "${COURSE_CRED_DIR}/argocd-admin.txt"
  gen_cred "${COURSE_CRED_DIR}/gitea-student.txt"
  gen_cred "${COURSE_CRED_DIR}/team-a-dev.txt"
  ensure_dir "${COURSE_SECRET_DIR}"; chmod 700 "${COURSE_SECRET_DIR}" 2>/dev/null || true
  gen_cred "${COURSE_SECRET_DIR}/gitea-teammate.txt"
  ok "credentials present (mode 0600)"
}

# ---------------------------------------------------------------------------
# Gitea.
# ---------------------------------------------------------------------------
ensure_gitea() {
  step "Ensuring Gitea container '${GITEA_CONTAINER}'"
  if [ "${REBUILD}" -eq 1 ] && docker ps -a --format '{{.Names}}' | grep -qx "${GITEA_CONTAINER}"; then
    log "rebuild: removing Gitea container and data volume"
    docker rm -f "${GITEA_CONTAINER}" >/dev/null 2>&1 || true
    docker volume rm gitea-data >/dev/null 2>&1 || true
  fi
  if docker ps -a --format '{{.Names}}' | grep -qx "${GITEA_CONTAINER}"; then
    docker start "${GITEA_CONTAINER}" >/dev/null 2>&1 || true
    ok "Gitea container already exists"
  else
    docker volume inspect gitea-data >/dev/null 2>&1 || docker volume create gitea-data >/dev/null
    docker run -d --name "${GITEA_CONTAINER}" --network "${DOCKER_NETWORK}" \
      -p "127.0.0.1:${GITEA_HOST_PORT}:3000" \
      -v gitea-data:/var/lib/gitea \
      -e GITEA__server__ROOT_URL="${GITEA_INTERNAL_URL}/" \
      -e GITEA__server__DOMAIN="${GITEA_CONTAINER}" \
      -e GITEA__server__HTTP_PORT=3000 \
      -e GITEA__server__SSH_DOMAIN="${GITEA_CONTAINER}" \
      -e GITEA__security__INSTALL_LOCK=true \
      -e GITEA__database__DB_TYPE=sqlite3 \
      -e GITEA__service__DISABLE_REGISTRATION=true \
      "${GITEA_IMAGE}" >/dev/null
    ok "Gitea container started"
  fi
  wait_for 120 "Gitea HTTP is up" \
    bash -c "curl -sf -o /dev/null '${GITEA_LOCAL_URL}/api/v1/version'"
}

ensure_gitea_user() {
  local user="$1" pw_file="$2" admin="$3"
  local pw; pw="$(read_cred "${pw_file}")"
  local extra=()
  [ "${admin}" = "1" ] && extra+=(--admin)
  # Expand a possibly-empty array safely under `set -u` (macOS bash 3.2).
  if docker exec -u git "${GITEA_CONTAINER}" gitea admin user create \
       --username "${user}" --password "${pw}" --email "${user}@example.com" \
       --must-change-password=false ${extra[@]+"${extra[@]}"} >/dev/null 2>&1; then
    ok "created Gitea user '${user}'"
  else
    # User already exists: make sure the password matches the credential file.
    # `change-password` defaults must-change-password to true, which would make
    # the Gitea API reject the account (HTTP 403); force it off.
    docker exec -u git "${GITEA_CONTAINER}" gitea admin user change-password \
      --username "${user}" --password "${pw}" --must-change-password=false >/dev/null 2>&1 || true
    ok "Gitea user '${user}' present"
  fi
}

ensure_gitea_users() {
  step "Ensuring Gitea users"
  ensure_gitea_user "${GITEA_ADMIN_USER}" "${COURSE_CRED_DIR}/gitea-student.txt" 1
  ensure_gitea_user "${GITEA_TEAMMATE_USER}" "${COURSE_SECRET_DIR}/gitea-teammate.txt" 0
}

# ---------------------------------------------------------------------------
# Local-mode git rewrite so the lab-gitea URLs in manifests also work from the
# build-machine shell (no /etc/hosts edit, no sudo).
# ---------------------------------------------------------------------------
setup_local_git() {
  [ "${COURSE_LOCAL}" = "1" ] || return 0
  step "Configuring git insteadOf for local mode"
  ensure_dir "${COURSE_USER_HOME}"
  local gc="${COURSE_USER_HOME}/.gitconfig"
  git config --file "${gc}" "url.http://localhost:${GITEA_HOST_PORT}/.insteadOf" \
    "${GITEA_INTERNAL_URL}/"
  ok "git rewrites ${GITEA_INTERNAL_URL}/ -> http://localhost:${GITEA_HOST_PORT}/ (via ${gc})"
}

# ---------------------------------------------------------------------------
# Argo CD + baseline objects.
# ---------------------------------------------------------------------------
argocd_login() {
  local pw; pw="$(read_cred "${COURSE_CRED_DIR}/argocd-admin.txt")"
  wait_for 120 "Argo CD API reachable on localhost:${ARGOCD_HOST_PORT}" \
    bash -c "curl -sk -o /dev/null 'https://localhost:${ARGOCD_HOST_PORT}/healthz'"
  argocd login "localhost:${ARGOCD_HOST_PORT}" --username admin --password "${pw}" --insecure >/dev/null
  ok "argocd CLI logged in"
}

ensure_workload_namespaces() {
  step "Creating workload namespaces"
  local ns
  for ns in argocd-access storefront-dev storefront-staging storefront-prod team-a platform-system; do
    kwork get ns "${ns}" >/dev/null 2>&1 || kwork create ns "${ns}" >/dev/null
  done
  ok "workload namespaces present"
}

apply_baseline_objects() {
  step "Applying CP-baseline objects"
  # Labeled in-cluster Secret so cluster selectors can address the mgmt cluster.
  kmgmt apply -f "${COURSE_REPOS_SRC}/platform-config/clusters/in-cluster.secret.yaml" >/dev/null
  # The hello-reconcile Application (Lab 1 starting point).
  kmgmt apply -f "${COURSE_REPOS_SRC}/hello-reconcile/argocd/hello-reconcile-app.yaml" >/dev/null
  ok "in-cluster Secret + hello-reconcile Application applied"
}

sync_hello_reconcile() {
  step "Syncing hello-reconcile to Synced/Healthy"
  argocd app sync hello-reconcile --timeout 180 >/dev/null
  argocd app wait hello-reconcile --health --timeout 180 >/dev/null
  ok "hello-reconcile is Synced/Healthy"
}

stage_lab_files() {
  step "Staging lab files under ${COURSE_LABFILES_DIR}"
  ensure_dir "${COURSE_LABFILES_DIR}"
  cp -R "${COURSE_ENV_DIR}/lab-files/." "${COURSE_LABFILES_DIR}/"
  ok "lab files staged"
}

# ---------------------------------------------------------------------------
# CP-baseline smoke test.
# ---------------------------------------------------------------------------
smoke_test() {
  step "CP-baseline smoke test"
  local fail=0
  check() { if "$@" >/dev/null 2>&1; then return 0; else return 1; fi; }
  if check docker network inspect "${DOCKER_NETWORK}"; then ok "network ${DOCKER_NETWORK}"; else err "network missing"; fail=1; fi
  if check kmgmt get nodes; then ok "mgmt cluster reachable"; else err "mgmt unreachable"; fail=1; fi
  if check kwork get nodes; then ok "workload cluster reachable"; else err "workload unreachable"; fail=1; fi
  if check kmgmt -n "${ARGOCD_NAMESPACE}" get deploy argocd-server; then ok "Argo CD installed"; else err "Argo CD missing"; fail=1; fi

  local sync health
  sync="$(argocd app get hello-reconcile -o json 2>/dev/null | yq -r '.status.sync.status' 2>/dev/null || echo '?')"
  health="$(argocd app get hello-reconcile -o json 2>/dev/null | yq -r '.status.health.status' 2>/dev/null || echo '?')"
  if [ "${sync}" = "Synced" ] && [ "${health}" = "Healthy" ]; then
    ok "hello-reconcile Synced/Healthy"
  else
    err "hello-reconcile is ${sync}/${health} (expected Synced/Healthy)"; fail=1
  fi

  # Cross-cluster name resolution proof: the workload node name resolves from the
  # application controller, the Pod that dials the workload API server in Lab 2
  # (repo-server already proved lab-gitea by cloning hello-reconcile). The Argo CD
  # images ship `getent` but not `nslookup`, so an nslookup probe always "fails".
  if kmgmt -n "${ARGOCD_NAMESPACE}" exec statefulset/argocd-application-controller -- \
       getent hosts "${WORKLOAD_NODE}" >/dev/null 2>&1; then
    ok "${WORKLOAD_NODE} resolves from a mgmt pod"
  else
    warn "${WORKLOAD_NODE} did not resolve from a mgmt pod (registration happens in Lab 2)"
  fi

  echo
  if [ "${fail}" -eq 0 ]; then
    printf '%sCP-baseline reached.%s Argo CD UI: https://localhost:%s  Gitea: %s\n' \
      "${_c_green}${_c_bold}" "${_c_reset}" "${ARGOCD_HOST_PORT}" "${GITEA_LOCAL_URL}"
    printf 'admin password: %s\n' "${COURSE_CRED_DIR}/argocd-admin.txt"
  else
    die "smoke test failed"
  fi
}

main() {
  require_cmd docker curl git openssl
  if ! docker info >/dev/null 2>&1; then die "Docker daemon is not running"; fi

  install_tools
  vendor_assets
  ensure_network
  ensure_cluster_mgmt
  ensure_cluster_workload
  import_images
  ensure_credentials
  ensure_gitea
  ensure_gitea_users
  setup_local_git
  bash "${SCRIPT_DIR}/seed-repos.sh"
  bash "${SCRIPT_DIR}/lib/refresh-coredns-hosts.sh" "${MGMT_CONTEXT}" "${WORKLOAD_CONTEXT}"
  bash "${SCRIPT_DIR}/apply-argocd-config.sh"
  argocd_login
  ensure_workload_namespaces
  apply_baseline_objects
  sync_hello_reconcile
  stage_lab_files
  smoke_test
}

main "$@"
