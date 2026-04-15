#!/bin/bash

# Limpar containers antigos
docker rm -f servidor_alvo atacante 2>/dev/null

# Criar container servidor_alvo (sem --mac-address pois será sobrescrito)
docker run -d --name servidor_alvo --hostname servidor_alvo \
    --network host \
    --cap-add NET_ADMIN --cap-add NET_RAW \
    servidor_alvo:latest sleep infinity


docker exec -d servidor_alvo ./entrypoint.sh




sleep 10
# Obter IP
SERVER_ALVO=$(ip a | grep -A3 -B2 'mtu 1500 qdisc fq_codel state UP' | grep 'inet' | grep -Eo '(((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)))' | sort | uniq | grep -v '255')


echo "IP do servidor: $SERVER_ALVO"

# Container atacante
docker run -d --name atacante --hostname atacante \
    --network none \
    --cap-add NET_ADMIN --cap-add NET_RAW \
    -e SERVER_IP="$SERVER_ALVO" \
    atacante:latest sleep infinity


sudo ip link add veth-host-02 type veth peer name veth-cont-02
sudo ip link set veth-cont-02 address 92:d0:c6:0a:29:33
sudo ip link set veth-host-02 master bridge-tap
sudo ip link set veth-host-02 up
C02PID=$(docker inspect -f '{{.State.Pid}}' atacante)
sudo ip link set veth-cont-02 netns "${C02PID}"
docker exec -it atacante ./entrypoint.sh
