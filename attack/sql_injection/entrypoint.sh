#!/bin/sh
TARGET_IP="${SERVER_IP:-192.168.56.111}"
echo "[+] Target SQL-INJECT: http://${TARGET_IP}"
TARGET_HOST=$(echo "${TARGET_IP}" | sed 's/http:\/\///' | sed 's/https:\/\///' | cut -d'/' -f1)
# Executa o sqlmap com a variável (usamos exec para substituir o shell pelo processo)
exec python3 /sqlmap/sqlmap.py -u "${TARGET_HOST}" --batch --level=3
