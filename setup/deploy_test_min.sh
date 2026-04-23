#!/bin/bash

docker rm -f test_min

docker run -d --name test_min --hostname test_min \
    --network none \
    --cap-add NET_ADMIN --cap-add NET_RAW \
atacante:latest sleep infinity


sudo ip link add veth-host-04 type veth peer name veth-cont-04
sudo ip link set veth-cont-04 address $s1
sudo ip link set veth-host-04 master bridge-tap
sudo ip link set veth-host-04 up
C02PID=$(docker inspect -f '{{.State.Pid}}' test_min)
sudo ip link set veth-cont-04 netns "${C02PID}"

docker exec -it test_min ./entrypoint2.sh
