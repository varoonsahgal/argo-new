#!/usr/bin/env bash
# F7 revert — restore the repo-server limits and re-apply Argo CD.
#
# Restoring the values in Git and re-running apply-argocd-config (honoring any
# active overlays such as the CP-capstone RBAC) rolls a healthy repo-server. This
# is exactly the repair the capstone solution prescribes.
set -euo pipefail
FAULT_ID="F7"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

step "F7 revert — restore repo-server limits via apply-argocd-config"
sha="$(cat "$(state_path main.sha)" 2>/dev/null || true)"
gitea_reset_main platform-config "${sha}"

# Re-apply Argo CD from the vendored chart + base values (512Mi limit), keeping
# any reset-managed overlays. This overwrites the live OOM patch.
# shellcheck disable=SC2119  # no extra overlays needed here; the list is read internally
apply_argocd_with_overlays

kmgmt -n "${ARGOCD_NAMESPACE}" rollout status deploy/argocd-repo-server --timeout=180s >/dev/null
ok "F7 reverted: argocd-repo-server healthy again"
