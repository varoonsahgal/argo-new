#!/usr/bin/env bash
# F2 verify — exit 0 iff the AppSet has generated Applications for in-cluster.
set -euo pipefail
FAULT_ID="F2"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

# The ApplicationSet git generator reconciles on its own interval; give it time.
for _ in $(seq 1 20); do
  if kmgmt -n "${ARGOCD_NAMESPACE}" get applications -o name 2>/dev/null | grep -q -- '-in-cluster'; then
    ok "F2 present: storefront-*-in-cluster Applications generated"
    exit 0
  fi
  sleep 3
done
warn "F2 not present: no *-in-cluster Applications found"
exit 1
