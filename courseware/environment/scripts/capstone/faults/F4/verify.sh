#!/usr/bin/env bash
# F4 verify — exit 0 iff the RoleBinding is missing (guaranteeing the 403).
set -euo pipefail
FAULT_ID="F4"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

if kwork -n storefront-prod get rolebinding argocd-deployer >/dev/null 2>&1; then
  warn "F4 not present: argocd-deployer RoleBinding still exists in storefront-prod"
  exit 1
fi
ok "F4 present: argocd-deployer RoleBinding absent in storefront-prod"
exit 0
