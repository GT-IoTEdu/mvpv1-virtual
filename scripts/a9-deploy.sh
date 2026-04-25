#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-/home/cristhian/wticifes2026-iotedu}"
HEALTH_URL="${HEALTH_URL:-https://iotedu.anonshield.org/health}"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-iotedu-anonshield}"
COMPOSE_FILES=(-f docker-compose.yml -f compose.a9.yml)
SERVICES=(db backend frontend sse_server)
if ip link show bridge-tap >/dev/null 2>&1; then
    SERVICES+=(zeek suricata_ids snort_ids)
fi

cd "$REPO_DIR"

exec 9>"$REPO_DIR/.deploy.lock"
flock -n 9 || { echo "deploy already in progress" >&2; exit 1; }

# Garante cron de backup do MySQL (idempotente)
BACKUP_LINE="0 3 * * * MYSQL_CONTAINER=${COMPOSE_PROJECT_NAME}-db-1 $REPO_DIR/scripts/backup-mysql.sh >> $REPO_DIR/.backup.log 2>&1"
if ! crontab -l 2>/dev/null | grep -qF "$REPO_DIR/scripts/backup-mysql.sh"; then
    (crontab -l 2>/dev/null; echo "$BACKUP_LINE") | crontab -
    echo "cron de backup instalado"
fi

export COMPOSE_PROJECT_NAME

docker compose "${COMPOSE_FILES[@]}" up -d --build "${SERVICES[@]}"
docker image prune -f >/dev/null

for _ in $(seq 1 30); do
    if curl -fsS --max-time 5 "$HEALTH_URL" >/dev/null 2>&1; then
        break
    fi
    sleep 2
done

if ! curl -fsS --max-time 5 "$HEALTH_URL" >/dev/null 2>&1; then
    echo "deploy: health probe failed for $HEALTH_URL" >&2
    docker compose "${COMPOSE_FILES[@]}" ps
    docker compose "${COMPOSE_FILES[@]}" logs --tail=40 backend
    exit 1
fi

# Smoke test: bate em todos os endpoints críticos. Falha aqui = deploy falhou.
BASE_URL="${HEALTH_URL%/health}"
bash "$REPO_DIR/scripts/smoke-test.sh" "$BASE_URL"
