#!/usr/bin/env bash
# F3 inject — root/child ownership fault (blueprint 8.9).
#
# A "teammate" commit to platform-config adds a SECOND root (team-root) plus a
# child (platform-agent-dup) that points at the SAME source as the existing
# platform-agent child (platform-components/agent -> platform-system). Two
# Applications now claim the same live Deployment, producing a shared-resource
# warning and ownership flapping.
#
#   apps/team-root.yaml         -> platform-root generates the team-root root
#   team-root/platform-agent-dup.yaml -> team-root generates the duplicate child
set -euo pipefail
FAULT_ID="F3"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

step "F3 inject — duplicate root/child ownership"

gitea_main_sha platform-config | save_state_file main.sha

wt="$(mktemp -d)"
teammate_clone platform-config "${wt}"

cat > "${wt}/apps/team-root.yaml" <<'YAML'
# Added by teammate: a second root Application under the App-of-Apps. It renders
# child Applications from the team-root/ path.
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: team-root
  namespace: argocd
spec:
  project: platform
  source:
    repoURL: http://lab-gitea:3000/course/platform-config.git
    targetRevision: main
    path: team-root
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
YAML

mkdir -p "${wt}/team-root"
cat > "${wt}/team-root/platform-agent-dup.yaml" <<'YAML'
# Added by teammate: a duplicate of the platform-agent child. It deploys the
# SAME source into the SAME namespace as platform-agent, so both Applications
# own the one platform-system agent Deployment.
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-agent-dup
  namespace: argocd
spec:
  project: platform
  source:
    repoURL: http://lab-gitea:3000/course/platform-components.git
    targetRevision: main
    path: agent
  destination:
    server: https://k3d-workload-server-0:6443
    namespace: platform-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
YAML

teammate_push "${wt}" "platform: add team-root app-of-apps"
rm -rf "${wt}"

app_hard_refresh "platform-root"
ok "F3 injected: team-root + platform-agent-dup added; expect shared-resource warning"
