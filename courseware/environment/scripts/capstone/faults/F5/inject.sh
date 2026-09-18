#!/usr/bin/env bash
# F5 inject — disconnected workload cluster via token rotation (blueprint 8.9).
#
# Delete and recreate the argocd-manager-token Secret on the WORKLOAD cluster.
# Kubernetes mints a brand-new bearer token, but the workload cluster Secret on
# the MANAGEMENT cluster still carries the OLD token, so Argo CD's calls now fail
# with 401 Unauthorized. Containers are NOT stopped — the cluster is up; only the
# credential is stale. This masks F4 and F6 (no connection means no sync at all).
set -euo pipefail
FAULT_ID="F5"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

token_present() {
  [ -n "$(kwork -n argocd-access get secret argocd-manager-token \
            -o jsonpath='{.data.token}' 2>/dev/null)" ]
}

step "F5 inject — rotate argocd-manager-token (401 Unauthorized)"

# Save the original Secret for reference (revert re-registers with a fresh token).
if kwork -n argocd-access get secret argocd-manager-token >/dev/null 2>&1; then
  kwork -n argocd-access get secret argocd-manager-token -o yaml \
    | yq 'del(.metadata.resourceVersion, .metadata.uid, .metadata.creationTimestamp,
              .metadata.generation, .metadata.managedFields, .status)' \
    | save_state_file token.yaml
fi

kwork -n argocd-access delete secret argocd-manager-token --ignore-not-found >/dev/null
kwork apply -f - >/dev/null <<'YAML'
apiVersion: v1
kind: Secret
metadata:
  name: argocd-manager-token
  namespace: argocd-access
  annotations:
    kubernetes.io/service-account.name: argocd-manager
type: kubernetes.io/service-account-token
YAML

wait_for 60 "new argocd-manager-token minted" token_present
ok "F5 injected: token rotated; management cluster Secret now holds a stale token"
