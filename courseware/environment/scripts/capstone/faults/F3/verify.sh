#!/usr/bin/env bash
# F3 verify — exit 0 iff the duplicate ownership is present.
set -euo pipefail
FAULT_ID="F3"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

# platform-root must render team-root, which must render platform-agent-dup.
for _ in $(seq 1 20); do
  if app_exists "platform-agent-dup"; then
    ok "F3 present: platform-agent-dup duplicates the platform-agent child"
    exit 0
  fi
  app_hard_refresh "platform-root"
  app_hard_refresh "team-root"
  sleep 3
done
warn "F3 not present: platform-agent-dup was not generated"
exit 1
