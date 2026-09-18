#!/usr/bin/env bash
# F7 inject — Argo CD component under resource pressure (blueprint 8.9).
#
# Lower the repo-server memory limit so its container is OOMKilled and enters
# CrashLoopBackOff. While repo-server is down, NOTHING renders, so every
# Application shows ComparisonError — this masks F1, F2, and F3.
#
# Two moves:
#   1) A "teammate" commit to platform-config argocd/values.yaml that lowers the
#      repo-server memory limit ("right-size argocd") — the evidence in git log.
#   2) The live repo-server Deployment is patched to that low limit so the
#      symptom is immediate and deterministic (blueprint K-9: value calibrated in
#      the validation pass; a CPU-starvation variant is the documented fallback).
set -euo pipefail
FAULT_ID="F7"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

# Calibrated by lab-tester on 2026-09-12 against this sandbox: at 64Mi the
# repo-server idles at ~40Mi and never OOMs, so the fault silently failed to
# appear. 32Mi is below the process's own start-up footprint, so the container is
# OOMKilled during start-up and enters CrashLoopBackOff deterministically.
OOM_LIMIT_MEM="32Mi"
OOM_REQUEST_MEM="24Mi"

step "F7 inject — starve argocd-repo-server memory (OOMKilled)"

gitea_main_sha platform-config | save_state_file main.sha

# (1) Evidence commit in git.
wt="$(mktemp -d)"
teammate_clone platform-config "${wt}"
yq -i ".repoServer.resources.limits.memory = \"${OOM_LIMIT_MEM}\""   "${wt}/argocd/values.yaml"
yq -i ".repoServer.resources.requests.memory = \"${OOM_REQUEST_MEM}\"" "${wt}/argocd/values.yaml"
teammate_push "${wt}" "argocd: right-size repo-server memory"
rm -rf "${wt}"

# (2) Make the running Deployment match, so the symptom appears now.
cname="$(kmgmt -n "${ARGOCD_NAMESPACE}" get deploy argocd-repo-server \
  -o jsonpath='{.spec.template.spec.containers[0].name}')"
kmgmt -n "${ARGOCD_NAMESPACE}" patch deploy argocd-repo-server --type strategic \
  -p "{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"${cname}\",\"resources\":{\"limits\":{\"memory\":\"${OOM_LIMIT_MEM}\"},\"requests\":{\"memory\":\"${OOM_REQUEST_MEM}\"}}}]}}}}" \
  >/dev/null

ok "F7 injected: repo-server memory limit ${OOM_LIMIT_MEM}; expect OOMKilled/CrashLoopBackOff"
