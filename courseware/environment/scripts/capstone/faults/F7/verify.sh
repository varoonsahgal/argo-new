#!/usr/bin/env bash
# F7 verify — exit 0 iff argocd-repo-server is not serving (OOM/CrashLoop).
set -euo pipefail
FAULT_ID="F7"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

repo_unavailable() {
  local avail
  avail="$(kmgmt -n "${ARGOCD_NAMESPACE}" get deploy argocd-repo-server \
    -o jsonpath='{.status.availableReplicas}' 2>/dev/null)"
  [ -z "${avail}" ] || [ "${avail}" = "0" ]
}

# Give the new (doomed) ReplicaSet time to roll and crash.
for _ in $(seq 1 20); do
  if repo_unavailable; then
    ok "F7 present: argocd-repo-server has no available replicas"
    exit 0
  fi
  sleep 3
done
warn "F7 not present: argocd-repo-server still reports available replicas"
exit 1
