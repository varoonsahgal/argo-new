#!/usr/bin/env bash
# refresh-coredns-hosts.sh — make lab-gitea and k3d-workload-server-0 resolvable
# from inside cluster pods (blueprint section 8.3, P-5).
#
# k3d injects Docker-network host records into CoreDNS at cluster-creation time,
# but those entries can be lost after a Docker or VM restart. This script writes
# *deterministic* records using the k3s-supported `coredns-custom` ConfigMap,
# which k3s imports via `import /etc/coredns/custom/*.override` inside its default
# server block and does NOT manage/overwrite. Running it is idempotent: it always
# replaces the whole ConfigMap and restarts CoreDNS.
#
# Usage: refresh-coredns-hosts.sh [context ...]   (defaults to k3d-mgmt)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

# Resolve a container's IPv4 address on the argocd-lab Docker network.
container_ip() {
  local name="$1"
  docker inspect -f \
    "{{ with index .NetworkSettings.Networks \"${DOCKER_NETWORK}\" }}{{ .IPAddress }}{{ end }}" \
    "$name" 2>/dev/null
}

# Emit one CoreDNS server block (YAML-indented by 4 spaces) that resolves a
# single lab hostname to an IP via its own `hosts` plugin. Each name gets its own
# block because k3s already runs a `hosts /etc/coredns/NodeHosts` plugin inside
# the default `.:53` block, and CoreDNS forbids two `hosts` plugins per server
# block. These blocks arrive via the k3s-imported `*.server` file, which is
# imported at the top level (a new server block), not inside `.:53`.
coredns_server_block() {
  local name="$1" ip="$2"
  printf '    %s:53 {\n' "${name}"
  printf '        hosts {\n'
  printf '            %s %s\n' "${ip}" "${name}"
  printf '            fallthrough\n'
  printf '        }\n'
  printf '    }\n'
}

refresh_context() {
  local ctx="$1"
  step "Refreshing CoreDNS host records on ${ctx}"

  local gitea_ip workload_ip
  gitea_ip="$(container_ip "${GITEA_CONTAINER}")"
  workload_ip="$(container_ip "${WORKLOAD_NODE}")"

  local server_blocks=""
  if [ -n "${gitea_ip}" ]; then
    server_blocks+="$(coredns_server_block "${GITEA_CONTAINER}" "${gitea_ip}")"$'\n'
    ok "${GITEA_CONTAINER} -> ${gitea_ip}"
  else
    warn "${GITEA_CONTAINER} not found on network ${DOCKER_NETWORK} (skipping its record)"
  fi
  if [ -n "${workload_ip}" ]; then
    server_blocks+="$(coredns_server_block "${WORKLOAD_NODE}" "${workload_ip}")"$'\n'
    ok "${WORKLOAD_NODE} -> ${workload_ip}"
  else
    warn "${WORKLOAD_NODE} not found on network ${DOCKER_NETWORK} (skipping its record)"
  fi

  if [ -z "${server_blocks}" ]; then
    warn "no host records to write for ${ctx}"
    return 0
  fi

  # Publish each record as its own server block via the k3s `*.server` import.
  local manifest
  manifest="$(cat <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns-custom
  namespace: kube-system
data:
  lab-hosts.server: |
${server_blocks}
YAML
)"

  printf '%s\n' "${manifest}" | kubectl --context "${ctx}" apply -f - >/dev/null
  kubectl --context "${ctx}" -n kube-system rollout restart deploy/coredns >/dev/null 2>&1 || true
  kubectl --context "${ctx}" -n kube-system rollout status deploy/coredns --timeout=60s >/dev/null 2>&1 || \
    warn "CoreDNS rollout status timed out on ${ctx} (records still applied)"
  ok "CoreDNS custom records applied on ${ctx}"
}

main() {
  require_cmd docker kubectl
  local contexts=("$@")
  if [ "${#contexts[@]}" -eq 0 ]; then
    contexts=("${MGMT_CONTEXT}")
  fi
  local ctx
  for ctx in "${contexts[@]}"; do
    refresh_context "${ctx}"
  done
}

main "$@"
