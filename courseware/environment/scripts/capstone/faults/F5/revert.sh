#!/usr/bin/env bash
# F5 revert — re-register the workload cluster with a fresh, valid token.
#
# The original token was invalidated when its Secret was deleted, so an exact
# byte restore is impossible; instead we perform the Lab 2 registration again
# (mint the current token, rewrite the management cluster Secret from the
# template). This reliably restores connectivity to the same cluster/ServiceAccount.
set -euo pipefail
FAULT_ID="F5"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

token_present() {
  [ -n "$(kwork -n argocd-access get secret argocd-manager-token \
            -o jsonpath='{.data.token}' 2>/dev/null)" ]
}

step "F5 revert — re-register workload cluster with a valid token"

# Ensure a token Secret exists and is populated.
if ! kwork -n argocd-access get secret argocd-manager-token >/dev/null 2>&1; then
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
fi
wait_for 60 "argocd-manager-token populated" token_present

token="$(kwork -n argocd-access get secret argocd-manager-token \
  -o go-template='{{ index .data "token" | base64decode }}')"
ca="$(kwork -n argocd-access get secret argocd-manager-token -o jsonpath='{.data.ca\.crt}')"

tmpl="${COURSE_REPOS_SRC}/platform-config/clusters/workload.secret.template.yaml"
content="$(cat "${tmpl}")"
content="${content//<TOKEN>/${token}}"
content="${content//<CA_DATA>/${ca}}"
printf '%s\n' "${content}" | kmgmt apply -f - >/dev/null

ok "F5 reverted: management cluster Secret re-registered with a valid token"
