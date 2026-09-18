#!/usr/bin/env bash
# capstone-check.sh — report the capstone restoration progress PER AREA, without
# naming any cause or fix (blueprint 8.9, CAP-P3).
#
#   capstone-check.sh [--local] [--instructor]
#
# It groups the observable signals into the areas a responder triages and prints
# "resolved" or "unresolved" for each. In its normal (participant) output it says
# NOTHING about which fault caused an area to be unresolved and never suggests a
# repair — an unresolved area is a question, not an answer. That separation is
# what keeps it usable both during the capstone and by the instructor.
#
#   --instructor   INSTRUCTOR ONLY. Adds a diagnostic line per unresolved area
#                  naming the signal that failed. Never run this in front of
#                  participants during the capstone: it hands them the triage.
#
# Exit code is 0 when every area is resolved, 1 otherwise (handy for the
# solution validation).
set -euo pipefail

# ---- parse flags before sourcing common ----
COURSE_LOCAL=0
INSTRUCTOR=0
for arg in "$@"; do
  case "${arg}" in
    --local) COURSE_LOCAL=1 ;;
    --instructor) INSTRUCTOR=1 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: ${arg}" >&2; exit 2 ;;
  esac
done
export COURSE_LOCAL

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# The Applications a fully-restored capstone platform should have (CP-capstone-restored).
EXPECTED_APPS="platform-root platform-quotas platform-netpol platform-agent \
storefront-dev-workload storefront-staging-workload storefront-prod-workload team-a-guestbook"

UNRESOLVED=0

# Print one area line and tally unresolved areas.
#
# The third argument is an INSTRUCTOR-ONLY diagnostic. It is suppressed unless
# --instructor was passed, because naming the failing signal in the participant's
# output would name the cause, and the capstone's whole point is that they find
# the cause themselves (blueprint 8.9).
area() {
  local label="$1" state="$2" detail="${3:-}"
  if [ "${state}" = "resolved" ]; then
    printf '  %s%-10s%s %s\n' "${_c_green}" "resolved" "${_c_reset}" "${label}"
  else
    printf '  %s%-10s%s %s\n' "${_c_red}" "unresolved" "${_c_reset}" "${label}"
    if [ "${INSTRUCTOR}" -eq 1 ] && [ -n "${detail}" ]; then
      printf '             %sinstructor-only:%s %s\n' "${_c_yellow}" "${_c_reset}" "${detail}"
    fi
    UNRESOLVED=$((UNRESOLVED + 1))
  fi
}

# --- helpers (kubectl only; offline) ---
app_names() { kmgmt -n "${ARGOCD_NAMESPACE}" get applications -o jsonpath='{.items[*].metadata.name}' 2>/dev/null; }
appf() { kmgmt -n "${ARGOCD_NAMESPACE}" get application "$1" -o jsonpath="{$2}" 2>/dev/null; }
deploy_available() {
  local d avail
  d="$1"
  avail="$(kmgmt -n "${ARGOCD_NAMESPACE}" get deploy "${d}" -o jsonpath='{.status.availableReplicas}' 2>/dev/null)"
  [ -n "${avail}" ] && [ "${avail}" != "0" ]
}

# --- Area 1: Argo CD platform components -----------------------------------
check_platform_components() {
  local d ok_all=1 down=""
  for d in argocd-repo-server argocd-server; do
    deploy_available "${d}" || { ok_all=0; down="${down} ${d}"; }
  done
  # application-controller is a StatefulSet.
  local ready
  ready="$(kmgmt -n "${ARGOCD_NAMESPACE}" get statefulset argocd-application-controller \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
  if [ -z "${ready}" ] || [ "${ready}" = "0" ]; then
    ok_all=0; down="${down} argocd-application-controller"
  fi
  if [ "${ok_all}" -eq 1 ]; then area "argo cd platform components" resolved
  else area "argo cd platform components" unresolved "no available replicas:${down}"; fi
}

# --- Area 2: Workload cluster connectivity ---------------------------------
check_connectivity() {
  local live stored
  live="$(kwork -n argocd-access get secret argocd-manager-token \
    -o go-template='{{ index .data "token" | base64decode }}' 2>/dev/null || true)"
  stored="$(kmgmt -n "${ARGOCD_NAMESPACE}" get secret cluster-workload \
    -o go-template='{{ index .data "config" | base64decode }}' 2>/dev/null | yq -r '.bearerToken' 2>/dev/null || true)"
  local detail=""
  kwork get ns >/dev/null 2>&1 || detail="workload API unreachable"
  if [ -z "${stored}" ] || [ "${stored}" = "null" ]; then
    detail="${detail:+${detail}; }cluster-workload Secret missing or has no bearerToken"
  elif [ "${live}" != "${stored}" ]; then
    detail="${detail:+${detail}; }stored bearerToken != live argocd-manager-token"
  fi
  if [ -z "${detail}" ]; then
    area "workload cluster connectivity" resolved
  else
    area "workload cluster connectivity" unresolved "${detail}"
  fi
}

# --- Area 3: Source rendering ----------------------------------------------
check_source_rendering() {
  local bad
  bad="$(kmgmt -n "${ARGOCD_NAMESPACE}" get applications -o json 2>/dev/null \
    | yq -r '.items[] | select(.status.conditions[]? | .type == "ComparisonError") | .metadata.name' 2>/dev/null \
    | tr '\n' ' ' | sed 's/ *$//')"
  if [ -z "${bad}" ]; then area "application source rendering" resolved
  else area "application source rendering" unresolved "ComparisonError on:${bad:+ }${bad}"; fi
}

# --- Area 4: Generation and ownership --------------------------------------
check_generation_ownership() {
  local name stray="" warned=""
  for name in $(app_names); do
    case " ${EXPECTED_APPS} " in
      *" ${name} "*) : ;;
      *) stray="${stray} ${name}" ;;
    esac
  done
  warned="$(kmgmt -n "${ARGOCD_NAMESPACE}" get applications -o json 2>/dev/null \
    | yq -r '.items[] | select(.status.conditions[]? | .type == "SharedResourceWarning") | .metadata.name' 2>/dev/null \
    | tr '\n' ' ' | sed 's/ *$//')"
  if [ -z "${stray# }" ] && [ -z "${warned}" ]; then
    area "application generation and ownership" resolved
  else
    area "application generation and ownership" unresolved \
      "unexpected Applications:${stray} | shared-owner warnings:${warned:+ }${warned}"
  fi
}

# --- Area 5: Deployment policy ---------------------------------------------
check_policy() {
  local name bad=""
  for name in $(app_names); do
    local phase msg
    phase="$(appf "${name}" '.status.operationState.phase')"
    msg="$(appf "${name}" '.status.operationState.message')"
    if [ "${phase}" = "Failed" ] && printf '%s' "${msg}" | grep -qiE 'forbidden|cannot |RBAC|denied'; then
      bad="${bad} ${name}"
    fi
  done
  if [ -z "${bad# }" ]; then area "deployment policy (permissions)" resolved
  else area "deployment policy (permissions)" unresolved "sync denied on:${bad}"; fi
}

# --- Area 6: Workload runtime health ---------------------------------------
check_runtime_health() {
  local name ok_all=1 unhealthy=""
  for name in ${EXPECTED_APPS}; do
    local h s
    h="$(appf "${name}" '.status.health.status')"
    s="$(appf "${name}" '.status.sync.status')"
    if [ "${h}" != "Healthy" ] || [ "${s}" != "Synced" ]; then
      ok_all=0
      unhealthy="${unhealthy} ${name}(${s:-absent}/${h:-absent})"
    fi
  done
  if [ "${ok_all}" -eq 1 ]; then area "workload runtime health" resolved
  else area "workload runtime health" unresolved "not Synced/Healthy:${unhealthy}"; fi
}

main() {
  require_cmd kubectl yq
  step "Capstone restoration status by area"
  check_platform_components
  check_connectivity
  check_source_rendering
  check_generation_ownership
  check_policy
  check_runtime_health
  echo
  if [ "${UNRESOLVED}" -eq 0 ]; then
    ok "all areas resolved"
    return 0
  fi
  warn "${UNRESOLVED} area(s) still unresolved"
  # A next action, without naming a cause. An unresolved area is a question,
  # not an answer: it tells the participant WHERE to look, never WHAT is wrong.
  printf '\n  %sNext:%s an unresolved area is a question, not an answer.\n' \
    "${_c_bold}" "${_c_reset}"
  printf '        Re-read that area'"'"'s block in capstone module 4 (the evidence toolbox)\n'
  printf '        and re-run its read-only commands. Statuses are measurements: check\n'
  printf '        again after a reconciliation cycle (~60s) before you change anything.\n'
  return 1
}

main
