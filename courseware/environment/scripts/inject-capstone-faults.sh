#!/usr/bin/env bash
# inject-capstone-faults.sh — orchestrate the capstone fault units (blueprint 8.9).
#
#   inject-capstone-faults.sh inject  {F1..F7|all}
#   inject-capstone-faults.sh verify  {F1..F7|all}
#   inject-capstone-faults.sh revert  {F1..F7|all}
#   inject-capstone-faults.sh status
#   (append --local to run against the build-machine sandbox)
#
# Each fault's mechanics live in scripts/capstone/faults/<F>/{inject,verify,revert}.sh.
# This orchestrator owns the shared bookkeeping the blueprint requires:
#   * inject  records pre-fault state under <capstone-state>/<F>.orig and writes
#             a marker <F>.marker;
#   * verify  exits 0 iff the fault's symptom is present;
#   * revert  restores exactly and clears the marker;
#   * status  lists which markers exist.
#   * all     injects in the order F1 F2 F3 F6 F4 F5 F7 and reverts in reverse.
set -euo pipefail

# ---- parse --local before sourcing common (which reads COURSE_LOCAL) ----
COURSE_LOCAL=0
ARGS=()
for arg in "$@"; do
  case "${arg}" in
    --local) COURSE_LOCAL=1 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) ARGS+=("${arg}") ;;
  esac
done
export COURSE_LOCAL

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

FAULTS_DIR="${COURSE_SCRIPTS_DIR}/capstone/faults"
CAP_STATE="${COURSE_CAPSTONE_STATE}"

marker_path() { printf '%s/%s.marker' "${CAP_STATE}" "$1"; }
state_dir()   { printf '%s/%s.orig' "${CAP_STATE}" "$1"; }

valid_fault() { case "$1" in F1|F2|F3|F4|F5|F6|F7) return 0 ;; *) return 1 ;; esac; }

# Reverse of FAULT_ORDER, for `revert all`.
# Built as a plain string, not an array: under `set -u`, bash 3.2 (the macOS
# build machine's /bin/bash) aborts on "${out[@]}" while the array is still
# empty, which broke `revert all` and every reset that calls it.
reverse_fault_order() {
  local out="" f
  for f in ${FAULT_ORDER}; do out="${f} ${out}"; done
  # shellcheck disable=SC2086  # deliberate word splitting: one fault per line
  printf '%s\n' ${out}
}

# Run one fault's inject/verify/revert script with its state dir wired in.
run_fault_script() {
  local f="$1" action="$2" script="${FAULTS_DIR}/$1/$2.sh"
  [ -f "${script}" ] || die "missing fault script: ${script}"
  FAULT_ID="${f}" FAULT_STATE_DIR="$(state_dir "${f}")" bash "${script}"
}

do_inject() {
  local f="$1"
  if [ -f "$(marker_path "${f}")" ]; then
    ok "${f} already injected (marker present); skipping"
    return 0
  fi
  ensure_dir "$(state_dir "${f}")"
  run_fault_script "${f}" inject
  date -u +%Y-%m-%dT%H:%M:%SZ > "$(marker_path "${f}")"
  ok "${f} marker written"
}

do_verify() {
  local f="$1"
  if run_fault_script "${f}" verify; then
    return 0
  fi
  return 1
}

do_revert() {
  local f="$1"
  if [ ! -f "$(marker_path "${f}")" ]; then
    ok "${f} not injected; nothing to revert"
    return 0
  fi
  run_fault_script "${f}" revert
  rm -f "$(marker_path "${f}")"
  ok "${f} marker cleared"
}

do_status() {
  step "Capstone fault status (${CAP_STATE})"
  local f ts any=0
  for f in ${FAULT_ORDER}; do
    if [ -f "$(marker_path "${f}")" ]; then
      ts="$(cat "$(marker_path "${f}")" 2>/dev/null || echo '?')"
      printf '  %sINJECTED%s %s  (since %s)\n' "${_c_yellow}" "${_c_reset}" "${f}" "${ts}"
      any=1
    else
      printf '  %sclean   %s %s\n' "${_c_green}" "${_c_reset}" "${f}"
    fi
  done
  [ "${any}" -eq 0 ] && ok "no faults injected"
  return 0
}

usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

main() {
  require_cmd kubectl git yq

  local action="${ARGS[0]:-}"
  local target="${ARGS[1]:-}"

  case "${action}" in
    status)
      do_status
      ;;
    inject|verify|revert)
      [ -n "${target}" ] || die "usage: inject-capstone-faults.sh ${action} {F1..F7|all}"
      if [ "${target}" = "all" ]; then
        local f rc=0
        case "${action}" in
          inject)
            for f in ${FAULT_ORDER}; do do_inject "${f}"; done
            ;;
          revert)
            while IFS= read -r f; do do_revert "${f}"; done < <(reverse_fault_order)
            ;;
          verify)
            for f in ${FAULT_ORDER}; do
              if do_verify "${f}"; then ok "${f} PRESENT"; else warn "${f} ABSENT"; rc=1; fi
            done
            return "${rc}"
            ;;
        esac
      else
        valid_fault "${target}" || die "unknown fault: ${target} (expected F1..F7 or all)"
        case "${action}" in
          inject) do_inject "${target}" ;;
          revert) do_revert "${target}" ;;
          verify)
            if do_verify "${target}"; then ok "${target} PRESENT"; return 0
            else warn "${target} ABSENT"; return 1; fi
            ;;
        esac
      fi
      ;;
    ""|-h|--help) usage ;;
    *) die "unknown action: ${action} (expected inject|verify|revert|status)" ;;
  esac
}

main
