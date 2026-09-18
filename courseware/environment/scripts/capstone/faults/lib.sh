# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR
# lib.sh — shared helpers for the capstone fault units F1..F7 (blueprint 8.9).
#
# This file is *sourced* by every fault's inject.sh / verify.sh / revert.sh; it
# is never executed on its own. It brings in the course-wide configuration and
# helpers from scripts/lib/common.sh and adds a small set of helpers the faults
# share: authoring "teammate" Git commits against Gitea, recording/restoring
# main SHAs, forcing Argo CD reconciliation, and reading Application/Secret
# fields deterministically with kubectl (no argocd-CLI session required).
#
# Contract with the orchestrator (inject-capstone-faults.sh):
#   FAULT_ID          the fault name, e.g. "F4" (each fault script sets it).
#   FAULT_STATE_DIR   where this fault records the exact pre-fault state so that
#                     revert restores it. Exported by the orchestrator; defaults
#                     here so a fault script can be run directly for debugging.

_faults_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "${_faults_lib_dir}/../../lib/common.sh"

: "${FAULT_ID:=unknown}"
: "${FAULT_STATE_DIR:=${COURSE_CAPSTONE_STATE}/${FAULT_ID}.orig}"

# ---------------------------------------------------------------------------
# Git-over-Gitea helpers.
#
# The committed manifests reference the in-cluster hostname http://lab-gitea:3000
# (which only resolves inside the clusters), so every push/clone here goes to
# Gitea over localhost with HTTP basic auth, exactly as seed-repos.sh does.
# ---------------------------------------------------------------------------

# Gitea clone URL for a repo, authenticated as a given user, from a password file.
_gitea_url() {
  local repo="$1" user="$2" pw_file="$3" pw
  pw="$(read_cred "${pw_file}")"
  printf 'http://%s:%s@localhost:%s/%s/%s.git' \
    "${user}" "${pw}" "${GITEA_HOST_PORT}" "${GITEA_ORG}" "${repo}"
}

# Print the current main-branch SHA of a course repo, as Gitea sees it.
gitea_main_sha() {
  local repo="$1" url
  url="$(_gitea_url "${repo}" "${GITEA_ADMIN_USER}" "${COURSE_CRED_DIR}/gitea-student.txt")"
  git ls-remote "${url}" refs/heads/main 2>/dev/null | awk 'NR==1 {print $1}'
}

# Clone a course repo's main into <dest>, ready to commit as <user>.
fault_clone() {
  local repo="$1" user="$2" pw_file="$3" dest="$4" url
  url="$(_gitea_url "${repo}" "${user}" "${pw_file}")"
  rm -rf "${dest}"
  git clone -q "${url}" "${dest}"
  git -C "${dest}" config user.name "${user}"
  git -C "${dest}" config user.email "${user}@example.com"
  git -C "${dest}" config commit.gpgsign false
}

# Clone as the teammate user (the author of realistic capstone fault commits).
teammate_clone() { fault_clone "$1" "${GITEA_TEAMMATE_USER}" "${COURSE_SECRET_DIR}/gitea-teammate.txt" "$2"; }

# Commit staged changes as teammate and push main to Gitea.
teammate_push() {
  local dest="$1" msg="$2"
  git -C "${dest}" add -A
  git -C "${dest}" commit -q -m "${msg}"
  git -C "${dest}" push -q origin main
}

# Force main of a repo back to a recorded SHA (exact revert of a git-based fault).
gitea_reset_main() {
  local repo="$1" sha="$2" dest
  [ -n "${sha}" ] || { warn "no recorded SHA for ${repo}; skipping git reset"; return 0; }
  dest="$(mktemp -d)"
  fault_clone "${repo}" "${GITEA_ADMIN_USER}" "${COURSE_CRED_DIR}/gitea-student.txt" "${dest}"
  git -C "${dest}" reset -q --hard "${sha}"
  git -C "${dest}" push -q -f origin main
  rm -rf "${dest}"
}

# Delete a tag in Gitea (used to remove a fault-created tag on revert).
gitea_delete_tag() {
  local repo="$1" tag="$2" url
  url="$(_gitea_url "${repo}" "${GITEA_ADMIN_USER}" "${COURSE_CRED_DIR}/gitea-student.txt")"
  git push -q "${url}" ":refs/tags/${tag}" >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------
# Argo CD Application helpers (kubectl only, so they work offline and need no
# argocd-CLI login session).
# ---------------------------------------------------------------------------

# Nudge an Application to reconcile now with a hard refresh.
app_hard_refresh() {
  kmgmt -n "${ARGOCD_NAMESPACE}" annotate application "$1" \
    argocd.argoproj.io/refresh=hard --overwrite >/dev/null 2>&1 || true
}

# Print a jsonpath field from an Application (empty if the app is absent).
app_field() {
  kmgmt -n "${ARGOCD_NAMESPACE}" get application "$1" -o jsonpath="{$2}" 2>/dev/null
}

# True if an Application currently exists.
app_exists() { kmgmt -n "${ARGOCD_NAMESPACE}" get application "$1" >/dev/null 2>&1; }

# Delete an Application WITHOUT cascade (orphan its live resources). Used where a
# stray/duplicate Application must go but a shared workload must survive.
app_delete_orphan() {
  local name="$1"
  app_exists "${name}" || return 0
  kmgmt -n "${ARGOCD_NAMESPACE}" patch application "${name}" --type merge \
    -p '{"metadata":{"finalizers":[]}}' >/dev/null 2>&1 || true
  kmgmt -n "${ARGOCD_NAMESPACE}" delete application "${name}" \
    --cascade=orphan --ignore-not-found >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------
# Argo CD reconfiguration honoring reset-managed overlays.
#
# reset-lab.sh records the currently-active Argo CD Helm values overlays (for
# example the CP-capstone RBAC overlay) in ${COURSE_STATE_DIR}/argocd-overlays.list
# (absolute paths, one per line; missing file means "base values only"). F7 must
# re-run apply-argocd-config with those same overlays so it never silently drops
# capstone RBAC while it changes the repo-server limit.
# ---------------------------------------------------------------------------
apply_argocd_with_overlays() {
  local overlays=() line
  if [ -f "${COURSE_STATE_DIR}/argocd-overlays.list" ]; then
    while IFS= read -r line; do
      [ -n "${line}" ] || continue
      overlays+=("${line}")
    done < "${COURSE_STATE_DIR}/argocd-overlays.list"
  fi
  # Expand a possibly-empty array safely under `set -u` (macOS bash 3.2).
  bash "${COURSE_SCRIPTS_DIR}/apply-argocd-config.sh" ${overlays[@]+"${overlays[@]}"} "$@"
}

# ---------------------------------------------------------------------------
# Small file helpers for recording/restoring pre-fault state.
# ---------------------------------------------------------------------------
save_state_file() { ensure_dir "${FAULT_STATE_DIR}"; cat > "${FAULT_STATE_DIR}/$1"; }
state_path()      { printf '%s/%s' "${FAULT_STATE_DIR}" "$1"; }
have_state()      { [ -s "${FAULT_STATE_DIR}/$1" ]; }
