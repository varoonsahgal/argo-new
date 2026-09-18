#!/usr/bin/env bash
# F1 verify — exit 0 iff the staging render failure symptom is present.
set -euo pipefail
FAULT_ID="F1"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

app="storefront-staging-workload"
app_exists "${app}" || { warn "F1 verify: ${app} not found"; exit 1; }

# Force a comparison, then look for a ComparisonError condition (render failure).
app_hard_refresh "${app}"
for _ in $(seq 1 15); do
  msg="$(app_field "${app}" '.status.conditions[?(@.type=="ComparisonError")].message')"
  if [ -n "${msg}" ]; then
    ok "F1 present: ${app} ComparisonError"
    exit 0
  fi
  sleep 2
done
warn "F1 not present: ${app} has no ComparisonError"
exit 1
