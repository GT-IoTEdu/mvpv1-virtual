#!/usr/bin/env bash
# Deploy do app iotedu-mvp no guasca via docker run direto (sem compose).
# Idempotente: derruba containers existentes e sobe versão nova de todos.
set -euo pipefail

REPO_DIR="${REPO_DIR:-/home/cristhian/mvpv1-virtual}"
HEALTH_URL="${HEALTH_URL:-https://mvp.iotedu.org/health}"
PROJECT="${PROJECT:-iotedu-mvp}"
NETWORK="${PROJECT}_net"
DB_VOLUME="${PROJECT}_db_data"

cd "$REPO_DIR"

exec 9>"$REPO_DIR/.deploy.lock"
flock -n 9 || { echo "deploy already in progress" >&2; exit 1; }

set -a; . ./backend/.env; set +a

log() { printf '\033[1;36m[guasca-deploy]\033[0m %s\n' "$*"; }

#--- 1. Rede + volume idempotentes -----------------------------------------
docker network inspect "$NETWORK" >/dev/null 2>&1 || docker network create "$NETWORK"
docker volume inspect "$DB_VOLUME" >/dev/null 2>&1 || docker volume create "$DB_VOLUME"

#--- 2. Build das 3 imagens (db usa mysql:8 oficial) -----------------------
log "build backend..."
docker build -q -t "${PROJECT}-backend" ./backend
log "build frontend..."
docker build -q -t "${PROJECT}-frontend" ./frontend
log "build sse_server..."
docker build -q -t "${PROJECT}-sse" ./ids/ids_log_monitor

#--- 3. Recreate containers (rm + run) -------------------------------------
restart_container() {
    local name="$1"; shift
    docker rm -f "$name" >/dev/null 2>&1 || true
    docker run -d --name "$name" --restart unless-stopped --network "$NETWORK" "$@"
}

log "starting db..."
restart_container "${PROJECT}-db" \
    --network-alias db \
    -v "${DB_VOLUME}:/var/lib/mysql" \
    -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
    -e MYSQL_DATABASE="$MYSQL_DB" \
    -e MYSQL_USER="$MYSQL_USER" \
    -e MYSQL_PASSWORD="$MYSQL_PASSWORD" \
    mysql:8

log "starting backend..."
restart_container "${PROJECT}-backend" \
    --network-alias backend \
    --env-file backend/.env \
    -p 127.0.0.1:8000:8000 \
    --add-host host.docker.internal:host-gateway \
    "${PROJECT}-backend"

log "starting frontend..."
restart_container "${PROJECT}-frontend" \
    --network-alias frontend \
    --env-file backend/.env \
    -p 127.0.0.1:3000:3000 \
    "${PROJECT}-frontend"

log "starting sse_server..."
restart_container "${PROJECT}-sse" \
    --network-alias sse_server \
    -v "${REPO_DIR}/ids/logs:/ids/logs:ro" \
    "${PROJECT}-sse"

docker image prune -f >/dev/null

#--- 4. Health probe -------------------------------------------------------
log "waiting for $HEALTH_URL..."
for _ in $(seq 1 30); do
    if curl -fsS --max-time 5 "$HEALTH_URL" >/dev/null 2>&1; then
        log "deploy ok"
        exit 0
    fi
    sleep 2
done

log "health check failed for $HEALTH_URL"
docker ps --filter "name=${PROJECT}-" --format 'table {{.Names}}\t{{.Status}}'
docker logs --tail=40 "${PROJECT}-backend" 2>&1 | tail -40
exit 1
