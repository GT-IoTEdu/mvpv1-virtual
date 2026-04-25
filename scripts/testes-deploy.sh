#!/usr/bin/env bash
# Deploy do iotedu-testes (staging) no guasca, mesma máquina do mvp.iotedu.org.
# Stack isolada: project, rede, volume e portas próprios.
set -euo pipefail

REPO_DIR="${REPO_DIR:-/home/cristhian/iotedu-testes}"
PROJECT="iotedu-testes"
DB_VOLUME="${DB_VOLUME:-iotedu-testes-db-data}"
DB_PASSWORDS="$REPO_DIR/backend/.env"
PUBLISH_HOST_PORTS="yes"
HOST_PORT_BACKEND="${HOST_PORT_BACKEND:-8001}"
HOST_PORT_FRONTEND="${HOST_PORT_FRONTEND:-3001}"
CADDY_CONTAINER=""
HEALTH_URL="${HEALTH_URL:-https://testes.iotedu.org/health}"
IDS_ENABLED="${IDS_ENABLED:-no}"   # staging não roda IDS

# shellcheck source=lib-deploy.sh
source "$(dirname "$0")/lib-deploy.sh"

deploy
