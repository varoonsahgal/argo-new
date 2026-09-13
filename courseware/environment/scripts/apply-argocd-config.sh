#!/usr/bin/env bash
# apply-argocd-config.sh — install/upgrade Argo CD from the vendored chart with
# the course values (blueprint section 8.6). Stands in for "the platform pipeline
# that manages Argo CD declaratively." Injects the admin and team-a-dev passwords
# at runtime from per-VM credential files so NO secret is ever committed.
#
# Usage: apply-argocd-config.sh [extra-values.yaml ...]
#   Extra values files are layered on top of the base values (later wins), so
#   passing a full values file is also a complete override:
#       apply-argocd-config.sh ~/platform-config/argocd/values.yaml
#
# WHERE THE BASE VALUES COME FROM (the declarative source), in priority order:
#   1. $ARGOCD_VALUES_FILE — an explicit base override. reset-lab.sh uses this to
#      pin the checkpoint's known-good values, so a reset never depends on what a
#      participant happens to have in Git.
#   2. platform-config `main`, as Gitea serves it — THE DEFAULT. Like a real
#      platform pipeline, this wrapper deploys what is committed and pushed, not
#      what is sitting unsaved in someone's working copy. Reading Git is what
#      makes "edit values.yaml, commit, push, run the wrapper" actually work.
#   3. The read-only seed copy shipped with the course payload — last resort,
#      used only when Gitea cannot be reached, and always announced with a warning.
# Everything is local (Gitea runs on this machine), so the default path is offline-safe.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

SEED_VALUES="${COURSE_REPOS_SRC}/platform-config/argocd/values.yaml"
GIT_CLONE_DIR=""          # set when the values come from Gitea; cleaned up at exit
BASE_VALUES=""
BASE_SOURCE=""

cleanup() { if [ -n "${GIT_CLONE_DIR}" ]; then rm -rf "${GIT_CLONE_DIR}"; fi; }
trap cleanup EXIT

# Shallow-clone platform-config main from the local Gitea. Prints nothing on
# success; returns non-zero (quietly) if Gitea is unreachable or the file is gone.
fetch_values_from_git() {
  local pw url dest
  [ -f "${COURSE_CRED_DIR}/gitea-student.txt" ] || return 1
  pw="$(tr -d '\n' < "${COURSE_CRED_DIR}/gitea-student.txt")"
  url="http://${GITEA_ADMIN_USER}:${pw}@localhost:${GITEA_HOST_PORT}/${GITEA_ORG}/platform-config.git"
  dest="$(mktemp -d)"
  # Quiet and non-interactive: never echo the URL (it carries the password) and
  # never block on a credential prompt.
  if GIT_TERMINAL_PROMPT=0 git clone -q --depth 1 --branch main --single-branch \
       "${url}" "${dest}" >/dev/null 2>&1 && [ -f "${dest}/argocd/values.yaml" ]; then
    GIT_CLONE_DIR="${dest}"
    return 0
  fi
  rm -rf "${dest}"
  return 1
}

resolve_base_values() {
  if [ -n "${ARGOCD_VALUES_FILE:-}" ]; then
    BASE_VALUES="${ARGOCD_VALUES_FILE}"
    BASE_SOURCE="explicit override (\$ARGOCD_VALUES_FILE)"
    [ -f "${BASE_VALUES}" ] || die "base values not found: ${BASE_VALUES}"
    return 0
  fi
  if fetch_values_from_git; then
    BASE_VALUES="${GIT_CLONE_DIR}/argocd/values.yaml"
    BASE_SOURCE="platform-config main (Gitea $(git -C "${GIT_CLONE_DIR}" rev-parse --short HEAD))"
    return 0
  fi
  [ -f "${SEED_VALUES}" ] || die "no values source available (Gitea unreachable and no seed copy at ${SEED_VALUES})"
  BASE_VALUES="${SEED_VALUES}"
  BASE_SOURCE="course payload seed copy"
  warn "could not read platform-config main from Gitea; falling back to the seed copy."
  warn "Changes you committed to platform-config will NOT be applied by this run."
}

# sha256 of stdin, on both macOS (shasum) and Linux (sha256sum).
sha256_hex() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'
  else sha256sum | awk '{print $1}'; fi
}

# Fingerprint of the credential files whose bcrypt hashes land in argocd-secret.
creds_fingerprint() {
  { cat "${COURSE_CRED_DIR}/argocd-admin.txt"
    [ -f "${COURSE_CRED_DIR}/team-a-dev.txt" ] && cat "${COURSE_CRED_DIR}/team-a-dev.txt"
    true
  } | sha256_hex
}

# Read one key out of the live argocd-secret (empty if absent).
live_secret_key() {
  kmgmt -n "${ARGOCD_NAMESPACE}" get secret argocd-secret \
    -o go-template="{{ index .data \"$1\" | base64decode }}" 2>/dev/null || true
}

# Write the runtime-secrets overlay: bcrypt hashes for the admin and team-a-dev
# accounts, injected from the per-VM credential files (never committed).
#
# Re-hashing on every run would be harmless for the password but NOT for the
# sessions: bcrypt is salted, so a fresh hash means a new `passwordMtime`, and
# Argo CD invalidates every issued token whenever that timestamp moves. In a lab
# that is a cruel red herring ("account password has changed since token issued")
# right after an unrelated config change. So when the credential files have not
# changed AND the cluster already carries their hashes, we pass the LIVE hash and
# mtime straight back through: the rendered Secret is byte-identical, nothing
# rolls, and existing CLI/UI sessions survive.
write_runtime_secrets() {
  local out="$1"
  local admin_hash admin_mtime team_hash team_mtime fp fp_file reuse=0
  ensure_dir "${COURSE_STATE_DIR}"
  fp_file="${COURSE_STATE_DIR}/argocd-credentials.fingerprint"
  fp="$(creds_fingerprint)"

  admin_hash="$(live_secret_key 'admin.password')"
  admin_mtime="$(live_secret_key 'admin.passwordMtime')"
  team_hash="$(live_secret_key 'accounts.team-a-dev.password')"
  team_mtime="$(live_secret_key 'accounts.team-a-dev.passwordMtime')"

  if [ -f "${fp_file}" ] && [ "$(cat "${fp_file}")" = "${fp}" ] \
     && [ -n "${admin_hash}" ] && [ -n "${admin_mtime}" ]; then
    reuse=1
    if [ -f "${COURSE_CRED_DIR}/team-a-dev.txt" ] && { [ -z "${team_hash}" ] || [ -z "${team_mtime}" ]; }; then
      reuse=0
    fi
  fi

  if [ "${reuse}" -eq 1 ]; then
    ok "account passwords unchanged: reusing the live hashes (existing logins stay valid)"
  else
    local admin_pw team_pw
    admin_pw="$(read_cred "${COURSE_CRED_DIR}/argocd-admin.txt")"
    admin_hash="$(argocd account bcrypt --password "${admin_pw}")"
    admin_mtime="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    team_hash=""; team_mtime=""
    if [ -f "${COURSE_CRED_DIR}/team-a-dev.txt" ]; then
      team_pw="$(read_cred "${COURSE_CRED_DIR}/team-a-dev.txt")"
      team_hash="$(argocd account bcrypt --password "${team_pw}")"
      team_mtime="${admin_mtime}"
    fi
    printf '%s' "${fp}" > "${fp_file}"
    warn "account passwords (re)stamped: every existing argocd session is now invalid; log in again"
  fi

  {
    echo "configs:"
    echo "  secret:"
    echo "    argocdServerAdminPassword: \"${admin_hash}\""
    echo "    argocdServerAdminPasswordMtime: \"${admin_mtime}\""
    # The team-a-dev local account password (Lab 5) lives in argocd-secret under
    # the accounts.<name>.password key. Added only if the credential exists.
    if [ -n "${team_hash}" ]; then
      echo "    extra:"
      echo "      accounts.team-a-dev.password: \"${team_hash}\""
      echo "      accounts.team-a-dev.passwordMtime: \"${team_mtime}\""
    fi
  } > "${out}"
}

main() {
  require_cmd helm kubectl argocd git
  [ -f "${COURSE_CHART_PATH}" ] || die "vendored chart not found: ${COURSE_CHART_PATH} (run bootstrap)"

  resolve_base_values

  step "Applying Argo CD configuration (chart ${ARGOCD_CHART_VERSION}, ${ARGOCD_VERSION})"
  ok "values source: ${BASE_SOURCE}"

  # Pre-create the Redis auth secret (redisSecretInit.enabled=false in values).
  # The chart's redis-secret-init pre-install hook Job shares a single, unweighted
  # pre-install hook with its own RBAC; under the pinned Helm 4 the Job can run
  # before its RoleBinding is effective and fail 403 (BackoffLimitExceeded),
  # hanging `helm --wait`. Provisioning the secret here removes that hook race.
  kmgmt get ns "${ARGOCD_NAMESPACE}" >/dev/null 2>&1 || kmgmt create ns "${ARGOCD_NAMESPACE}" >/dev/null
  if ! kmgmt -n "${ARGOCD_NAMESPACE}" get secret argocd-redis >/dev/null 2>&1; then
    local redis_pw
    # Bound the input first so nothing downstream closes an infinite pipe (SIGPIPE
    # under `set -o pipefail`); cut reads its finite input to EOF.
    redis_pw="$(head -c 512 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9' | cut -c1-32)"
    kmgmt -n "${ARGOCD_NAMESPACE}" create secret generic argocd-redis \
      --from-literal=auth="${redis_pw}" >/dev/null
    kmgmt -n "${ARGOCD_NAMESPACE}" label secret argocd-redis \
      app.kubernetes.io/name=argocd-redis \
      app.kubernetes.io/part-of=argocd --overwrite >/dev/null
    ok "pre-created argocd-redis secret (redisSecretInit disabled)"
  fi

  local runtime_secrets; runtime_secrets="$(mktemp)"
  chmod 600 "${runtime_secrets}"
  write_runtime_secrets "${runtime_secrets}"

  # Assemble -f arguments: base, runtime secrets, then any extra overlays.
  local helm_args=(upgrade --install argocd "${COURSE_CHART_PATH}"
    --kube-context "${MGMT_CONTEXT}"
    -n "${ARGOCD_NAMESPACE}" --create-namespace
    -f "${BASE_VALUES}" -f "${runtime_secrets}")
  local extra
  for extra in "$@"; do
    [ -f "${extra}" ] || die "extra values file not found: ${extra}"
    helm_args+=(-f "${extra}")
    ok "overlay: ${extra}"
  done
  # --force-conflicts: Helm v4 applies server-side, so any field another manager
  # has written directly (for example a `kubectl patch` on a Deployment) makes the
  # upgrade fail with "conflict occurred while applying object". The platform's
  # declarative configuration is the source of truth here, so the wrapper takes
  # ownership back instead of refusing to run.
  helm_args+=(--force-conflicts --wait --timeout 300s)

  helm "${helm_args[@]}"
  rm -f "${runtime_secrets}"

  ok "Argo CD release applied"

  # A concise readiness check independent of --wait.
  kmgmt -n "${ARGOCD_NAMESPACE}" rollout status deploy/argocd-server --timeout=180s >/dev/null
  kmgmt -n "${ARGOCD_NAMESPACE}" rollout status deploy/argocd-repo-server --timeout=180s >/dev/null
  ok "argocd-server and argocd-repo-server are ready"
}

main "$@"
