#!/usr/bin/env bash
# F3 revert — remove the duplicate WITHOUT cascade, then restore Git.
#
# Deleting team-root with cascade would prune platform-agent-dup which, because
# it shares the live Deployment with platform-agent, would delete the running
# workload. So the strays are orphan-deleted first (leaving the shared workload
# owned by the real platform-agent), and only then is Git restored.
set -euo pipefail
FAULT_ID="F3"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

step "F3 revert — restore Git, then orphan-delete strays"

# Order matters (observed 2026-09-12): team-root syncs automatically with
# selfHeal, and platform-root does the same for team-root itself. Deleting the
# child first simply let the root recreate it, so `revert all` returned success
# while platform-agent-dup was still present. Restore Git first so neither root
# wants the strays any more, then delete root-before-child, and retry until they
# are really gone.
sha="$(cat "$(state_path main.sha)" 2>/dev/null || true)"
gitea_reset_main platform-config "${sha}"
app_hard_refresh "platform-root"

strays_gone() { ! app_exists team-root && ! app_exists platform-agent-dup; }

for _ in 1 2 3 4 5 6 7 8 9 10; do
  strays_gone && break
  app_delete_orphan "team-root"
  app_delete_orphan "platform-agent-dup"
  sleep 3
done

if strays_gone; then
  ok "F3 reverted: duplicates removed; platform-agent retains sole ownership"
else
  die "F3 revert: team-root/platform-agent-dup still present after 10 attempts"
fi
