#!/usr/bin/env bash
# F2 inject — generation blast-radius fault (blueprint 8.9).
#
# A "teammate" empties the clusters generator's `cluster-role: workload` selector
# in platform-config applicationsets/storefront.yaml, so the matrix now matches
# EVERY registered cluster — including in-cluster (the management cluster). The
# ApplicationSet then generates storefront-{dev,staging,prod}-in-cluster in
# addition to the intended -workload set: an unexpectedly large blast radius.
#
# The teammate does BOTH halves of a realistic change: they merge it to main AND
# apply it. That matters, because nothing in this environment reconciles the
# ApplicationSet object itself from Git — the platform team applies it with
# kubectl (capstone change path C). Pushing the commit alone would leave the live
# generator untouched and no fault would ever appear.
set -euo pipefail
FAULT_ID="F2"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

APPSET="storefront"
SELECTOR_PATH='.spec.generators[0].matrix.generators[0].clusters.selector'

step "F2 inject — ApplicationSet selector drop (generation)"

kmgmt -n "${ARGOCD_NAMESPACE}" get applicationset "${APPSET}" >/dev/null 2>&1 \
  || die "F2 inject: ApplicationSet ${APPSET} not found (expected at CP-capstone)"

# Record both halves of the pre-fault state: the repo's main SHA, and the live
# cluster selector, so revert restores the object exactly as well as the commit.
gitea_main_sha platform-config | save_state_file main.sha
kmgmt -n "${ARGOCD_NAMESPACE}" get applicationset "${APPSET}" \
  -o jsonpath="{${SELECTOR_PATH}}" | save_state_file selector.json

wt="$(mktemp -d)"
teammate_clone platform-config "${wt}"
# Empty the cluster selector so it matches all clusters (incl. in-cluster).
yq -i "${SELECTOR_PATH}.matchLabels = {}" "${wt}/applicationsets/${APPSET}.yaml"
teammate_push "${wt}" "storefront appset: simplify cluster selector"

# ...and apply what they merged, exactly as the platform team applies this object.
kmgmt apply -f "${wt}/applicationsets/${APPSET}.yaml" >/dev/null
rm -rf "${wt}"

ok "F2 injected: selector emptied and applied; expect stray storefront-*-in-cluster Applications"
