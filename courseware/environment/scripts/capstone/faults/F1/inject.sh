#!/usr/bin/env bash
# F1 inject — source/render fault (blueprint 8.9).
#
# A "teammate" commit to storefront-gitops blanks the `required` image.tag in
# envs/staging/values.yaml (a plausible "cleanup"). Rendering then fails FOR
# STAGING ONLY, so the storefront-staging-workload Application reports a
# ComparisonError. This deliberately differs from lab-03 E5 part A (a missing
# values file); here the file is present but the required value is empty.
set -euo pipefail
FAULT_ID="F1"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

step "F1 inject — staging render failure (source/render)"

# Record the exact pre-fault main SHA so revert restores it byte-for-byte.
gitea_main_sha storefront-gitops | save_state_file main.sha

wt="$(mktemp -d)"
teammate_clone storefront-gitops "${wt}"
# Blank the required image.tag for staging only.
yq -i '.image.tag = ""' "${wt}/envs/staging/values.yaml"
teammate_push "${wt}" "staging: drop stale image.tag pin (values cleanup)"
rm -rf "${wt}"

app_hard_refresh "storefront-staging-workload"
ok "F1 injected: staging image.tag blanked; expect ComparisonError on storefront-staging-workload"
