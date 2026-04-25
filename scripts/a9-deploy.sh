#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-/home/cristhian/wticifes2026-iotedu}"
HEALTH_URL="${HEALTH_URL:-https://iotedu.anonshield.org/health}"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-iotedu-anonshield}"
COMPOSE_FILES=(-f docker-compose.yml -f compose.a9.yml)
SERVICES=(db backend frontend sse_server zeek suricata_ids snort_ids)

cd "$REPO_DIR"

exec 9>"$REPO_DIR/.deploy.lock"
flock -n 9 || { echo "deploy already in progress" >&2; exit 1; }

export COMPOSE_PROJECT_NAME

docker compose "${COMPOSE_FILES[@]}" up -d --build "${SERVICES[@]}"
docker image prune -f >/dev/null

for _ in $(seq 1 30); do
    if curl -fsS --max-time 5 "$HEALTH_URL" >/dev/null 2>&1; then
        echo "deploy ok"
        exit 0
    fi
    sleep 2
done

echo "deploy: health check failed for $HEALTH_URL" >&2
docker compose "${COMPOSE_FILES[@]}" ps
docker compose "${COMPOSE_FILES[@]}" logs --tail=40 backend
exit 1
