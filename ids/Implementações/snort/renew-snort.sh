#!/bin/bash

docker stop snort_ids

sudo truncate -s 0 $(docker inspect --format='{{.LogPath}}' snort_ids)

sudo truncate -s 0 ./logs/*

docker restart snort_ids
