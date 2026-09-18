#!/usr/bin/env bash
# F4 inject — Kubernetes RBAC denial (blueprint 8.9).
#
# Delete the argocd-deployer RoleBinding in storefront-prod on the WORKLOAD
# cluster. Argo CD's ServiceAccount keeps get/list (it can still compare) but
# loses write permission there, so any sync of storefront-prod fails with a 403
# Forbidden. The exact RoleBinding is saved first so revert restores it.
set -euo pipefail
FAULT_ID="F4"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

step "F4 inject — delete argocd-deployer RoleBinding in storefront-prod"

if kwork -n storefront-prod get rolebinding argocd-deployer >/dev/null 2>&1; then
  kwork -n storefront-prod get rolebinding argocd-deployer -o yaml \
    | yq 'del(.metadata.resourceVersion, .metadata.uid, .metadata.creationTimestamp,
              .metadata.generation, .metadata.managedFields, .status)' \
    | save_state_file rolebinding.yaml
  kwork -n storefront-prod delete rolebinding argocd-deployer >/dev/null
  ok "F4 injected: argocd-deployer RoleBinding removed from storefront-prod (403 on sync)"
else
  warn "F4 inject: RoleBinding already absent (idempotent)"
fi

app_hard_refresh "storefront-prod-workload"
