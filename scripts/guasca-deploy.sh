#!/usr/bin/env bash
# Deploy do iotedu-mvp no guasca (sem docker compose).
# Caddy roda nativo no host → backend/frontend publicam em 127.0.0.1.
set -euo pipefail

REPO_DIR="${REPO_DIR:-/home/cristhian/mvpv1-virtual}"
PROJECT="iotedu-mvp"
DB_VOLUME="${DB_VOLUME:-iotedu-mvp-db-data}"
DB_PASSWORDS="$REPO_DIR/backend/.env"
PUBLISH_HOST_PORTS="yes"         # Caddy nativo no host bate em 127.0.0.1:8000/3000
CADDY_CONTAINER=""               # nenhum: Caddy é serviço do host
HEALTH_URL="${HEALTH_URL:-https://mvp.iotedu.org/health}"
IDS_ENABLED="${IDS_ENABLED:-auto}"

# shellcheck source=lib-deploy.sh
source "$(dirname "$0")/lib-deploy.sh"

deploy
