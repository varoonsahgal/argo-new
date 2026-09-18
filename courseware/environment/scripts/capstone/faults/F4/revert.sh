#!/usr/bin/env bash
# F4 revert — restore the argocd-deployer RoleBinding in storefront-prod.
set -euo pipefail
FAULT_ID="F4"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

step "F4 revert — restore argocd-deployer RoleBinding"
if have_state rolebinding.yaml; then
  kwork apply -f "$(state_path rolebinding.yaml)" >/dev/null
  ok "F4 reverted: RoleBinding restored from saved state"
else
  # Fallback: re-apply the whole least-privilege RBAC bundle (idempotent).
  rbac="${COURSE_LABFILES_DIR}/lab-02/workload-rbac.yaml"
  [ -f "${rbac}" ] || rbac="${COURSE_ENV_DIR}/lab-files/lab-02/workload-rbac.yaml"
  kwork apply -f "${rbac}" >/dev/null
  ok "F4 reverted: RBAC re-applied from ${rbac}"
fi
app_hard_refresh "storefront-prod-workload"
