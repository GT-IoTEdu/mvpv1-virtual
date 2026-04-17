#!/bin/bash

docker stop suricata_ids

sudo truncate -s 0 $(docker inspect --format='{{.LogPath}}' suricata_ids)

sudo truncate -s 0 ./logs/*

docker restart suricata_ids
