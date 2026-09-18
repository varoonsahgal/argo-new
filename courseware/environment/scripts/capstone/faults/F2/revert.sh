#!/usr/bin/env bash
# F2 revert — restore the selector (in Git AND on the cluster) and remove the
# stray in-cluster Applications.
#
# Three moves, mirroring the two halves of the injection plus its consequence:
#   1) force platform-config main back to the recorded pre-fault SHA;
#   2) put the live ApplicationSet's cluster selector back — reverting the commit
#      does not touch the applied object, exactly as in the real repair;
#   3) delete the already-generated in-cluster Applications. applicationsSync is
#      create-update, so the controller never deletes what it generated; these
#      must go deliberately. They target in-cluster/argocd, which the storefront
#      AppProject forbids, so they deployed nothing — an orphan delete is safe.
set -euo pipefail
FAULT_ID="F2"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

APPSET="storefront"
SELECTOR_PATH='/spec/generators/0/matrix/generators/0/clusters/selector'

step "F2 revert — restore selector (Git + live object) and delete strays"
sha="$(cat "$(state_path main.sha)" 2>/dev/null || true)"
gitea_reset_main platform-config "${sha}"

selector="$(cat "$(state_path selector.json)" 2>/dev/null || true)"
if [ -n "${selector}" ] && kmgmt -n "${ARGOCD_NAMESPACE}" get applicationset "${APPSET}" >/dev/null 2>&1; then
  kmgmt -n "${ARGOCD_NAMESPACE}" patch applicationset "${APPSET}" --type json \
    -p "[{\"op\":\"replace\",\"path\":\"${SELECTOR_PATH}\",\"value\":${selector}}]" >/dev/null
  ok "live ApplicationSet selector restored to ${selector}"
else
  warn "F2 revert: no recorded selector (or no ApplicationSet); skipping the live patch"
fi

for env in dev staging prod; do
  app_delete_orphan "storefront-${env}-in-cluster"
done
ok "F2 reverted: selector restored; in-cluster Applications removed"
