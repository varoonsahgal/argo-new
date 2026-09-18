#!/usr/bin/env bash
# F6 inject — degraded workload plus noisy/misleading drift (blueprint 8.9).
#
# Two moves by "teammate":
#   1) Create the immutable tag storefront-1.1.0 whose chart has a BAD readiness
#      path (so pods never pass readiness -> Degraded) and hpa.enabled=true with
#      minReplicas ABOVE the rendered replicaCount (so spec.replicas flaps ->
#      noisy OutOfSync). The bad chart lives only under the tag, not on main.
#   2) Point envs/prod/config.yaml at storefront-1.1.0 and let prod sync to it.
set -euo pipefail
FAULT_ID="F6"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

step "F6 inject — bad prod release storefront-1.1.0 + prod promotion"

gitea_main_sha storefront-gitops | save_state_file main.sha

wt="$(mktemp -d)"
teammate_clone storefront-gitops "${wt}"

# (1) Build the bad release commit, tag it, push ONLY the tag, then drop the
#     commit from the working branch so main stays clean.
yq -i '.probes.readinessPath = "/not-ready"' "${wt}/charts/storefront/values.yaml"
yq -i '.hpa.enabled = true'                  "${wt}/charts/storefront/values.yaml"
yq -i '.hpa.minReplicas = 5'                 "${wt}/charts/storefront/values.yaml"
git -C "${wt}" add -A
git -C "${wt}" commit -q -m "release storefront-1.1.0"
git -C "${wt}" tag -f storefront-1.1.0
git -C "${wt}" push -q -f origin refs/tags/storefront-1.1.0
git -C "${wt}" reset -q --hard origin/main

# (2) Promote prod to the bad tag on main.
yq -i '.targetRevision = "storefront-1.1.0"' "${wt}/envs/prod/config.yaml"
teammate_push "${wt}" "prod: promote to storefront-1.1.0"
rm -rf "${wt}"

app_hard_refresh "storefront-prod-workload"
ok "F6 injected: prod promoted to storefront-1.1.0 (bad readiness + HPA/replicas conflict)"
