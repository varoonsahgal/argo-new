#!/usr/bin/env bash
# F6 revert — restore prod to storefront-1.0.0 and delete the bad tag.
set -euo pipefail
FAULT_ID="F6"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

step "F6 revert — roll prod back and remove storefront-1.1.0"
sha="$(cat "$(state_path main.sha)" 2>/dev/null || true)"
gitea_reset_main storefront-gitops "${sha}"
gitea_delete_tag storefront-gitops storefront-1.1.0
app_hard_refresh "storefront-prod-workload"
ok "F6 reverted: prod back to storefront-1.0.0; bad tag deleted"
