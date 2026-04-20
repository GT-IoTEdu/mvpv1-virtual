#!/usr/bin/env bash



ip link set lo up
ip link set veth-cont-04 name eth0
ip link set eth0 up
dhclient -v eth0

ping 8.8.8.8
