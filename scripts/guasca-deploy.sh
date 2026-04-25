#!/usr/bin/env bash
# Deploy do app iotedu-mvp no guasca (mesmo padrão de a9-deploy.sh).
# Usa docker compose com overlay específico do host. IDS containers
# (zeek/suricata_ids/snort_ids) só sobem se a bridge-tap existir no
# host — provisionada por scripts/setup-host.sh.
set -euo pipefail

REPO_DIR="${REPO_DIR:-/home/cristhian/mvpv1-virtual}"
HEALTH_URL="${HEALTH_URL:-https://mvp.iotedu.org/health}"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-iotedu-mvp}"
COMPOSE_FILES=(-f docker-compose.yml -f compose.guasca.yml)
SERVICES=(db backend frontend sse_server)
if ip link show bridge-tap >/dev/null 2>&1; then
    SERVICES+=(zeek suricata_ids snort_ids)
fi

cd "$REPO_DIR"

exec 9>"$REPO_DIR/.deploy.lock"
flock -n 9 || { echo "deploy already in progress" >&2; exit 1; }

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
