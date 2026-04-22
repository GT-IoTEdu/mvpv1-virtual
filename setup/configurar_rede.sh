#!/bin/bash
sudo ip link add bridge-tap type bridge
sudo ip link set bridge-tap up
sudo ip tuntap add dev tap0 mode tap
sudo ip link set tap0 master bridge-tap
sudo ip link set tap0 up
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Get the parent directory
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Change to parent directory so all commands run from there
cd "$PARENT_DIR" || exit 1



docker build ./attack/target-server  -t servidor_alvo:latest --no-cache


# Criar container servidor_alvo (sem --mac-address pois será sobrescrito)
docker run -d --name servidor_alvo --hostname servidor_alvo \
    --network host \
    --cap-add NET_ADMIN --cap-add NET_RAW \
    servidor_alvo:latest sleep infinity

docker exec -d servidor_alvo ./entrypoint.sh

sleep 10

docker build ./attack/ddos -t ddos:latest --no-cache

docker build ./attack/sql_injection -t sql_injection:latest --no-cache

docker build ./attack/ping_flood -t ping_flood:latest --no-cache

docker build ./attack/dns_tunneling -t dns_tunneling:latest --no-cache

docker build ./attack/brute_force_ssh -t brute_force_ssh:latest --no-cache
