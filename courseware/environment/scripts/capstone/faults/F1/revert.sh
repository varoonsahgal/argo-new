#!/usr/bin/env bash
# F1 revert — restore storefront-gitops main to its pre-fault SHA.
set -euo pipefail
FAULT_ID="F1"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

step "F1 revert — restore staging values"
sha="$(cat "$(state_path main.sha)" 2>/dev/null || true)"
gitea_reset_main storefront-gitops "${sha}"
app_hard_refresh "storefront-staging-workload"
ok "F1 reverted: storefront-gitops main back to ${sha:-<recorded SHA>}"
