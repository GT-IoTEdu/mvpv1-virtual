#!/usr/bin/env bash
# Deploy do iotedu-anonshield no a9 (sem docker compose).
# Caddy roda em container e proxia por nome de container na rede do projeto.
set -euo pipefail

REPO_DIR="${REPO_DIR:-/home/cristhian/wticifes2026-iotedu}"
PROJECT="iotedu-anonshield"
DB_VOLUME="${DB_VOLUME:-iotedu-anonshield_iotedu_db_data}"   # preserva volume legado do compose
DB_PASSWORDS="$REPO_DIR/backend/.env"
PUBLISH_HOST_PORTS="no"          # Caddy alcança via rede docker
CADDY_CONTAINER="web-caddy-1"    # conecta o Caddy à rede ${PROJECT}-net
HEALTH_URL="${HEALTH_URL:-https://iotedu.anonshield.org/health}"
IDS_ENABLED="${IDS_ENABLED:-auto}"

# shellcheck source=lib-deploy.sh
source "$(dirname "$0")/lib-deploy.sh"

deploy
