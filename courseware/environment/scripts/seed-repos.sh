#!/usr/bin/env bash
# seed-repos.sh — build the five course Git repositories in Gitea, with a
# checkpoint history (tags cp-baseline ... cp-capstone-restored), and mirror them
# locally for offline resets (blueprint sections 8.7, 8.8).
#
# Repos are built from courseware/environment/repos/<repo>/ (the cp-baseline
# tree). Per-checkpoint deltas live under
# courseware/environment/checkpoints/<CP>/repos/<repo>/ (files to add/replace,
# plus an optional .remove list). Each checkpoint becomes a Git tag; `main` is
# left at cp-baseline, and reset-lab.sh force-moves it as needed.
#
# Requires: Gitea running with admin user `student` and user `teammate` already
# created by bootstrap-vm.sh. Idempotent: safe to re-run.
set -euo pipefail

# --local targets the build-machine sandbox, the same flag reset-lab.sh takes.
# It must be read before sourcing common.sh, which resolves paths from it.
: "${COURSE_LOCAL:=0}"
for arg in "$@"; do
  case "${arg}" in
    --local) COURSE_LOCAL=1 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  esac
done
export COURSE_LOCAL

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

GITEA_API="${GITEA_LOCAL_URL}/api/v1"

gitea_pw() { read_cred "${COURSE_CRED_DIR}/gitea-student.txt"; }

# curl helper against the Gitea API as the student admin. Prints HTTP status on
# the last line via -w so callers can branch on it.
api() {
  local method="$1" path="$2" body="${3:-}"
  local pw; pw="$(gitea_pw)"
  if [ -n "${body}" ]; then
    curl -sS -o /dev/null -w '%{http_code}' -u "${GITEA_ADMIN_USER}:${pw}" \
      -H 'Content-Type: application/json' -X "${method}" "${GITEA_API}${path}" -d "${body}"
  else
    curl -sS -o /dev/null -w '%{http_code}' -u "${GITEA_ADMIN_USER}:${pw}" \
      -X "${method}" "${GITEA_API}${path}"
  fi
}

wait_for_gitea() {
  step "Waiting for Gitea API at ${GITEA_LOCAL_URL}"
  wait_for 120 "Gitea API is up" \
    bash -c "curl -sf -o /dev/null '${GITEA_LOCAL_URL}/api/v1/version'"
}

ensure_org() {
  step "Ensuring Gitea org '${GITEA_ORG}'"
  local code
  code="$(api GET "/orgs/${GITEA_ORG}")"
  if [ "${code}" = "200" ]; then
    ok "org '${GITEA_ORG}' exists"
  else
    code="$(api POST "/orgs" "{\"username\":\"${GITEA_ORG}\",\"visibility\":\"public\"}")"
    case "${code}" in
      201|200) ok "created org '${GITEA_ORG}'" ;;
      *) die "failed to create org '${GITEA_ORG}' (HTTP ${code})" ;;
    esac
  fi
  # The org MUST be public visibility: a private org hides even its public repos
  # from anonymous users, which breaks Lab 1's public-read hello-reconcile repo.
  # Per-repo `private` flags still fence the private repos. Idempotent.
  api PATCH "/orgs/${GITEA_ORG}" "{\"visibility\":\"public\"}" >/dev/null || true
}

ensure_repo() {
  local repo="$1" private="$2"
  local code
  code="$(api GET "/repos/${GITEA_ORG}/${repo}")"
  if [ "${code}" = "200" ]; then
    ok "repo '${repo}' exists"
  else
    code="$(api POST "/orgs/${GITEA_ORG}/repos" \
      "{\"name\":\"${repo}\",\"private\":${private},\"auto_init\":false,\"default_branch\":\"main\"}")"
    case "${code}" in
      201|200) ok "created repo '${repo}' (private=${private})" ;;
      *) die "failed to create repo '${repo}' (HTTP ${code})" ;;
    esac
  fi
  # Ensure visibility matches the desired state (idempotent).
  api PATCH "/repos/${GITEA_ORG}/${repo}" "{\"private\":${private}}" >/dev/null || true
  # Give the teammate user write access so fault injection can author commits.
  api PUT "/repos/${GITEA_ORG}/${repo}/collaborators/${GITEA_TEAMMATE_USER}" \
    "{\"permission\":\"write\"}" >/dev/null || true
}

# Copy an overlay directory onto the working tree, then process its .remove list.
apply_overlay() {
  local overlay="$1" work="$2"
  [ -d "${overlay}" ] || return 0
  local rel
  while IFS= read -r -d '' rel; do
    rel="${rel#./}"
    mkdir -p "${work}/$(dirname "${rel}")"
    cp "${overlay}/${rel}" "${work}/${rel}"
  done < <(cd "${overlay}" && find . -type f ! -name '.remove' -print0)
  if [ -f "${overlay}/.remove" ]; then
    local path
    while IFS= read -r path; do
      [ -n "${path}" ] || continue
      case "${path}" in \#*) continue ;; esac
      rm -f "${work}/${path}"
    done < "${overlay}/.remove"
  fi
}

# Build a repo's full checkpoint history in a temp working dir, create the local
# bare mirror, and push everything to Gitea.
seed_one() {
  local repo="$1" private="$2"
  step "Seeding repo '${repo}'"

  ensure_repo "${repo}" "${private}"

  local work; work="$(mktemp -d)"
  git -C "${work}" init -q -b main
  git -C "${work}" config user.name "${GITEA_ADMIN_USER}"
  git -C "${work}" config user.email "student@example.com"
  git -C "${work}" config commit.gpgsign false

  local cp first=1
  for cp in ${CHECKPOINTS}; do
    if [ "${first}" -eq 1 ]; then
      # Baseline tree.
      cp -R "${COURSE_REPOS_SRC}/${repo}/." "${work}/"
      first=0
    else
      apply_overlay "${COURSE_CHECKPOINTS_SRC}/${cp}/repos/${repo}" "${work}"
    fi
    # Stage everything including deletions.
    git -C "${work}" add -A
    # Only commit if there is a change or it is the very first checkpoint.
    if [ -n "$(git -C "${work}" status --porcelain)" ] || \
       ! git -C "${work}" rev-parse HEAD >/dev/null 2>&1; then
      git -C "${work}" commit -q -m "checkpoint ${cp}" --allow-empty
    fi
    # Tag (idempotent within this fresh repo).
    local tag; tag="cp-${cp#CP-}"
    git -C "${work}" tag -f "${tag}" >/dev/null
  done

  # Release tag pinned by content (blueprint 8.7): storefront-gitops
  # envs/prod/config.yaml sets targetRevision: storefront-1.0.0. Without this tag
  # storefront-prod-workload shows ComparisonError "unable to resolve
  # 'storefront-1.0.0' to a commit SHA" at CP-lab-05 and later. cp-baseline is the
  # known-good 1.0.0 chart. The repo's only checkpoint overlay (CP-lab-04) moves
  # envs/dev and envs/staging from podinfo 6.14.1 to 6.15.0 (the Lab 3 promotion);
  # the chart and envs/prod, the only files prod reads at this tag, are identical
  # at every checkpoint, so prod still runs 6.15.0. The local mirror carries the
  # tag, so every reset-lab.sh re-pushes it (--tags).
  if [ "${repo}" = "storefront-gitops" ]; then
    git -C "${work}" tag -f storefront-1.0.0 cp-baseline >/dev/null
  fi

  # main starts at cp-baseline; reset-lab.sh advances it per checkpoint.
  # Use checkout -B so this succeeds even though 'main' is the checked-out branch
  # (git refuses `branch -f` on the current branch).
  git -C "${work}" checkout -q -B main cp-baseline

  # Local bare mirror for offline resets.
  ensure_dir "${COURSE_SEED_DIR}"
  rm -rf "${COURSE_SEED_DIR}/${repo}.git"
  git clone -q --bare "${work}" "${COURSE_SEED_DIR}/${repo}.git"

  # Push to Gitea over localhost with basic auth (the committed manifests use the
  # lab-gitea hostname, which only resolves inside the clusters).
  local pw; pw="$(gitea_pw)"
  local push_url="http://${GITEA_ADMIN_USER}:${pw}@localhost:${GITEA_HOST_PORT}/${GITEA_ORG}/${repo}.git"
  git -C "${work}" push -q -f "${push_url}" main --tags
  ok "pushed '${repo}' (main@cp-baseline + all cp-* tags)"

  rm -rf "${work}"
}

main() {
  require_cmd git curl
  wait_for_gitea
  ensure_org

  # hello-reconcile is public-read (Lab 1 needs no credentials); the rest private.
  local repo private
  for repo in ${COURSE_REPOS}; do
    if [ "${repo}" = "hello-reconcile" ]; then private="false"; else private="true"; fi
    seed_one "${repo}" "${private}"
  done

  step "Seed complete"
  ok "local mirrors under ${COURSE_SEED_DIR}"
  ok "Gitea org '${GITEA_ORG}' has ${COURSE_REPOS// /, }"
}

main "$@"
