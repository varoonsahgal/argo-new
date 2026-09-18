#!/usr/bin/env bash
# F6 verify — exit 0 iff prod is pinned to the bad tag storefront-1.1.0.
set -euo pipefail
FAULT_ID="F6"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

app="storefront-prod-workload"
for _ in $(seq 1 20); do
  rev="$(app_field "${app}" '.spec.source.targetRevision')"
  if [ "${rev}" = "storefront-1.1.0" ]; then
    ok "F6 present: ${app} pinned to storefront-1.1.0"
    exit 0
  fi
  sleep 3
done
warn "F6 not present: ${app} is not pinned to storefront-1.1.0"
exit 1
