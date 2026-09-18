# shellcheck shell=bash
# common.sh — shared configuration and helpers for every course environment script.
#
# This file is *sourced*, never executed. It sets the pinned versions, the
# canonical names from blueprint section 8.3, the on-disk layout, and small
# logging/tooling helpers. Both VM mode (default) and local build-machine mode
# (`--local`) resolve their paths here so the two behave identically.
#
# Nothing in this file has side effects beyond exporting variables and defining
# functions, so it is safe to source from any script.

# ---------------------------------------------------------------------------
# Strict-ish defaults. Individual scripts still set their own `set -euo pipefail`.
# ---------------------------------------------------------------------------
if [ -n "${BASH_VERSION:-}" ]; then
  set -o pipefail
fi

# ---------------------------------------------------------------------------
# Pinned versions (blueprint section 8.2; verified in section 12).
# ---------------------------------------------------------------------------
export ARGOCD_VERSION="v3.5.2"
export ARGOCD_CHART_VERSION="10.8.4"
export ARGOCD_CHART_FILE="argo-cd-${ARGOCD_CHART_VERSION}.tgz"
export ARGOCD_CHART_URL="https://github.com/argoproj/argo-helm/releases/download/argo-cd-${ARGOCD_CHART_VERSION}/${ARGOCD_CHART_FILE}"
export K3S_IMAGE="rancher/k3s:v1.35.8-k3s1"
export K3D_MIN_VERSION="v5.9.0"
export KUBECTL_VERSION="v1.35.8"
export HELM_VERSION="v4.2.1"
export ARGOCD_CLI_VERSION="v3.5.2"
export YQ_VERSION="v4.48.1"
export GITEA_IMAGE="gitea/gitea:1.27.3-rootless"
export PODINFO_IMAGE="stefanprodan/podinfo:6.15.0"
# The previous podinfo release. storefront dev/staging start on it at cp-baseline
# through cp-lab-03, so Lab 3 Exercise 2 can promote 6.14.1 -> 6.15.0 with both
# images already on the workload cluster (no registry pull in class). cp-lab-04
# moves dev/staging back to PODINFO_IMAGE. Verified on Docker Hub 2026-09-13.
export PODINFO_PREV_IMAGE="stefanprodan/podinfo:6.14.1"
# P-16 pins resolved by environment-engineer:
export BUSYBOX_IMAGE="busybox:1.37.0"
export REDIS_IMAGE_REPO="public.ecr.aws/docker/library/redis"
export REDIS_IMAGE_TAG="8.6.4-alpine"

# ---------------------------------------------------------------------------
# Canonical names (blueprint section 8.3). Downstream guides use these verbatim.
# ---------------------------------------------------------------------------
export DOCKER_NETWORK="argocd-lab"
export MGMT_CLUSTER="mgmt"
export WORKLOAD_CLUSTER="workload"
export MGMT_CONTEXT="k3d-mgmt"
export WORKLOAD_CONTEXT="k3d-workload"
export MGMT_API_PORT="6550"
export WORKLOAD_API_PORT="6551"
export MGMT_NODE="k3d-mgmt-server-0"
export WORKLOAD_NODE="k3d-workload-server-0"
export ARGOCD_NAMESPACE="argocd"
export ARGOCD_NODEPORT="30443"
export ARGOCD_HOST_PORT="8443"
export GITEA_CONTAINER="lab-gitea"
export GITEA_HOST_PORT="3000"
export GITEA_ORG="course"
export GITEA_INTERNAL_URL="http://${GITEA_CONTAINER}:${GITEA_HOST_PORT}"
export GITEA_LOCAL_URL="http://localhost:${GITEA_HOST_PORT}"
export GITEA_ADMIN_USER="student"
export GITEA_TEAMMATE_USER="teammate"

# Ordered checkpoint list (blueprint section 8.8).
export CHECKPOINTS="CP-baseline CP-lab-02 CP-lab-03 CP-lab-04 CP-lab-05 CP-capstone CP-capstone-restored"
# Repositories seeded into Gitea (blueprint section 8.7).
export COURSE_REPOS="hello-reconcile storefront-gitops platform-config platform-components team-a-apps"
# Fault-injection order for `all` (blueprint section 8.9).
export FAULT_ORDER="F1 F2 F3 F6 F4 F5 F7"

# ---------------------------------------------------------------------------
# Layout. COURSE_HOME holds vendored assets (chart, image tarballs, seed
# mirrors, checkpoint bundles). In --local mode everything lives under the
# build user's home so no sudo is ever required.
# ---------------------------------------------------------------------------
# COURSE_LOCAL is exported by a script that saw `--local` before sourcing helpers
# that depend on it; default to VM mode.
: "${COURSE_LOCAL:=0}"

# Resolve the environment/ directory (the parent of scripts/) so scripts can be
# run from anywhere, including directly out of the git checkout in local mode.
_common_source="${BASH_SOURCE[0]}"
COURSE_SCRIPTS_DIR="$(cd "$(dirname "${_common_source}")/.." && pwd)"
export COURSE_SCRIPTS_DIR
COURSE_ENV_DIR="$(cd "${COURSE_SCRIPTS_DIR}/.." && pwd)"
export COURSE_ENV_DIR
export COURSE_REPOS_SRC="${COURSE_ENV_DIR}/repos"
export COURSE_CHECKPOINTS_SRC="${COURSE_ENV_DIR}/checkpoints"

if [ "${COURSE_LOCAL}" = "1" ]; then
  export COURSE_HOME="${COURSE_HOME:-$HOME/.argocd-course}"
  export COURSE_TOOLS_DIR="${COURSE_TOOLS_DIR:-$HOME/.argocd-course/bin}"
  export COURSE_USER_HOME="${COURSE_USER_HOME:-$HOME/.argocd-course/student-home}"
else
  export COURSE_HOME="${COURSE_HOME:-/opt/course}"
  export COURSE_TOOLS_DIR="${COURSE_TOOLS_DIR:-/usr/local/bin}"
  export COURSE_USER_HOME="${COURSE_USER_HOME:-/home/student}"
fi

export COURSE_CHART_DIR="${COURSE_HOME}/charts"
export COURSE_CHART_PATH="${COURSE_CHART_DIR}/${ARGOCD_CHART_FILE}"
export COURSE_SEED_DIR="${COURSE_HOME}/seed-repos"
export COURSE_IMAGE_DIR="${COURSE_HOME}/images"
export COURSE_CHECKPOINT_DIR="${COURSE_HOME}/checkpoints"
export COURSE_STATE_DIR="${COURSE_HOME}/state"
export COURSE_CRED_DIR="${COURSE_CRED_DIR:-${COURSE_USER_HOME}/course/credentials}"
export COURSE_SECRET_DIR="${COURSE_SECRET_DIR:-${COURSE_HOME}/secrets}"
export COURSE_CAPSTONE_STATE="${COURSE_STATE_DIR}/capstone"
export COURSE_LABFILES_DIR="${COURSE_USER_HOME}/course/lab-files"

# Put the pinned tools first on PATH for every lab-facing command.
export PATH="${COURSE_TOOLS_DIR}:${PATH}"

# ---------------------------------------------------------------------------
# Logging helpers. Colour only when stdout is a TTY.
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
  _c_reset=$'\033[0m'; _c_blue=$'\033[34m'; _c_green=$'\033[32m'
  _c_yellow=$'\033[33m'; _c_red=$'\033[31m'; _c_bold=$'\033[1m'
else
  _c_reset=""; _c_blue=""; _c_green=""; _c_yellow=""; _c_red=""; _c_bold=""
fi

log()   { printf '%s[ %s ]%s %s\n' "${_c_blue}" "$(date +%H:%M:%S)" "${_c_reset}" "$*"; }
step()  { printf '\n%s==>%s %s%s%s\n' "${_c_bold}${_c_blue}" "${_c_reset}" "${_c_bold}" "$*" "${_c_reset}"; }
ok()    { printf '%s  ok%s %s\n' "${_c_green}" "${_c_reset}" "$*"; }
warn()  { printf '%swarn%s %s\n' "${_c_yellow}" "${_c_reset}" "$*" >&2; }
err()   { printf '%s FAIL%s %s\n' "${_c_red}" "${_c_reset}" "$*" >&2; }
die()   { err "$*"; exit 1; }

# ---------------------------------------------------------------------------
# Tooling helpers.
# ---------------------------------------------------------------------------
require_cmd() {
  # require_cmd docker kubectl helm ...
  local missing=0 c
  for c in "$@"; do
    if ! command -v "$c" >/dev/null 2>&1; then
      err "required command not found on PATH: $c"
      missing=1
    fi
  done
  [ "$missing" -eq 0 ] || die "install the missing tools and retry"
}

# kubectl bound to a named context, always using the pinned binary.
kc() { kubectl --context "$1" "${@:2}"; }
kmgmt() { kubectl --context "${MGMT_CONTEXT}" "$@"; }
kwork() { kubectl --context "${WORKLOAD_CONTEXT}" "$@"; }

# Read a credential file, trimming trailing newline. Fails loudly if absent.
read_cred() {
  local f="$1"
  [ -f "$f" ] || die "credential file missing: $f (run bootstrap first)"
  tr -d '\n' < "$f"
}

# Idempotently ensure a directory exists.
ensure_dir() { mkdir -p "$1"; }

# Wait until a shell predicate succeeds or a timeout elapses.
# wait_for <timeout-seconds> <description> <command...>
wait_for() {
  local timeout="$1" desc="$2"; shift 2
  local start; start=$(date +%s)
  while true; do
    if "$@" >/dev/null 2>&1; then
      ok "$desc"
      return 0
    fi
    if [ $(( $(date +%s) - start )) -ge "$timeout" ]; then
      err "timed out after ${timeout}s waiting for: $desc"
      return 1
    fi
    sleep 3
  done
}

# The Gitea clone URL Argo CD uses (by container name). In local mode the VM
# shell resolves lab-gitea via /etc/hosts; on the build machine we rewrite to
# localhost through git insteadOf (set up by bootstrap), so this URL is always
# the one committed into manifests.
repo_url() { printf '%s/%s/%s.git' "${GITEA_INTERNAL_URL}" "${GITEA_ORG}" "$1"; }

# ---------------------------------------------------------------------------
# Checkpoint materialization. Composite a repo's tree at a given checkpoint by
# applying the baseline plus every overlay up to and including <upto>. Overlays
# live under checkpoints/<CP>/repos/<repo>/ (files to add/replace, plus an
# optional .remove list). Used by reset-lab.sh; seed-repos.sh builds the full
# history the same way.
# ---------------------------------------------------------------------------
_apply_overlay() {
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

materialize_repo() {
  local repo="$1" upto="$2" dest="$3"
  rm -rf "${dest}"; mkdir -p "${dest}"
  cp -R "${COURSE_REPOS_SRC}/${repo}/." "${dest}/"
  local cp
  for cp in ${CHECKPOINTS}; do
    if [ "${cp}" != "CP-baseline" ]; then
      _apply_overlay "${COURSE_CHECKPOINTS_SRC}/${cp}/repos/${repo}" "${dest}"
    fi
    [ "${cp}" = "${upto}" ] && break
  done
}

# Numeric index of a checkpoint in delivery order (CP-baseline=0 ...
# CP-capstone-restored=6). Prints -1 for an unknown checkpoint.
checkpoint_index() {
  local target="$1" i=0 cp
  for cp in ${CHECKPOINTS}; do
    if [ "${cp}" = "${target}" ]; then echo "${i}"; return 0; fi
    i=$((i + 1))
  done
  echo "-1"
}

# The Git tag for a checkpoint (CP-lab-03 -> cp-lab-03).
checkpoint_tag() { printf 'cp-%s' "${1#CP-}"; }

