#!/usr/bin/env bash
# F5 verify — exit 0 iff the stored token no longer matches the live SA token.
#
# A mismatch guarantees the 401: the management cluster Secret authenticates with
# a token the workload cluster will now reject.
set -euo pipefail
FAULT_ID="F5"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

live_token="$(kwork -n argocd-access get secret argocd-manager-token \
  -o go-template='{{ index .data "token" | base64decode }}' 2>/dev/null || true)"
stored_token="$(kmgmt -n "${ARGOCD_NAMESPACE}" get secret cluster-workload \
  -o go-template='{{ index .data "config" | base64decode }}' 2>/dev/null | yq -r '.bearerToken' 2>/dev/null || true)"

if [ -z "${stored_token}" ] || [ "${stored_token}" = "null" ]; then
  warn "F5 verify: could not read stored bearerToken (cluster Secret missing?)"
  exit 1
fi
if [ "${live_token}" != "${stored_token}" ]; then
  ok "F5 present: management Secret token no longer matches the workload SA token (401)"
  exit 0
fi
warn "F5 not present: stored token still matches the live SA token"
exit 1
