#!/usr/bin/env bash
# Bootstrap idempotente de uma máquina Linux nova pra rodar IoT-EDU.
# Faz tudo que NÃO depende de secrets ou painel externo:
#   - instala docker e caddy se faltarem
#   - clona o repo
#   - opcionalmente roda setup-host.sh (IDS)
#   - gera backend/.env com placeholders e secrets aleatórios pra DB/sessão
#   - adiciona vhost no /etc/caddy/Caddyfile e recarrega Caddy
#   - cria alias 'iotedu-deploy' no .bashrc
#
# Uso:
#   bash scripts/bootstrap-new-host.sh <dominio>
#
# Variáveis:
#   ENABLE_IDS=yes         roda setup-host.sh (precisa sudo)
#   CADDY_MODE=host         (default) instala Caddy via apt e usa Caddyfile do sistema
#   CADDY_MODE=container    NÃO instala Caddy no host; sobe Caddy como container
#                           do próprio projeto, gerenciado pelo deploy
#   REPO_URL=...           sobrescreve o repo padrão
#   REPO_DIR=...           onde clonar (default: ~/iotedu)
#   PROJECT=...            prefixo dos containers (default: derivado do domínio)

set -euo pipefail

DOMAIN="${1:-}"
[ -n "$DOMAIN" ] || { echo "uso: bash $0 <dominio>" >&2; exit 1; }

REPO_URL="${REPO_URL:-https://github.com/GT-IoTEdu/mvpv1-virtual.git}"
REPO_DIR="${REPO_DIR:-$HOME/iotedu}"
PROJECT="${PROJECT:-iotedu-$(echo "$DOMAIN" | tr '.' '-')}"
ENABLE_IDS="${ENABLE_IDS:-no}"
CADDY_MODE="${CADDY_MODE:-host}"
case "$CADDY_MODE" in host|container) ;; *) echo "CADDY_MODE inválido: $CADDY_MODE (use host ou container)" >&2; exit 1 ;; esac

log() { printf '\033[1;32m[bootstrap]\033[0m %s\n' "$*"; }

# --- 1. Docker -----------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
    log "instalando Docker"
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker "$USER"
    log "Docker instalado — pode precisar 'newgrp docker' ou novo shell"
else
    log "Docker já instalado ($(docker --version))"
fi

# --- 2. Caddy (host ou container) ----------------------------------------
if [ "$CADDY_MODE" = "host" ]; then
    if ! command -v caddy >/dev/null 2>&1; then
        log "instalando Caddy nativo (apt)"
        sudo apt-get update -qq
        sudo apt-get install -y -qq debian-keyring debian-archive-keyring apt-transport-https curl
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
            | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
            | sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
        sudo apt-get update -qq
        sudo apt-get install -y -qq caddy
        sudo systemctl enable --now caddy
    else
        log "Caddy nativo já instalado ($(caddy version 2>&1 | head -1))"
    fi
else
    log "CADDY_MODE=container — Caddy será gerenciado pelo deploy script"
fi

# --- 3. Clone do repo ----------------------------------------------------
if [ ! -d "$REPO_DIR/.git" ]; then
    log "clonando repo em $REPO_DIR"
    git clone "$REPO_URL" "$REPO_DIR"
else
    log "repo já em $REPO_DIR"
fi

# --- 4. Setup IDS (opcional) --------------------------------------------
if [ "$ENABLE_IDS" = "yes" ]; then
    log "rodando setup-host.sh (IDS)"
    sudo bash "$REPO_DIR/scripts/setup-host.sh"
fi

# --- 5. backend/.env com placeholders ------------------------------------
ENV_FILE="$REPO_DIR/backend/.env"
if [ ! -f "$ENV_FILE" ]; then
    log "criando $ENV_FILE com secrets aleatórios pra DB/sessão"
    SESSION=$(openssl rand -hex 32)
    DBPASS=$(openssl rand -hex 16)
    ROOTPASS=$(openssl rand -hex 16)
    cat > "$ENV_FILE" <<EOF
# === DB (gerado automaticamente — pode trocar) ===
MYSQL_ROOT_PASSWORD=${ROOTPASS}
MYSQL_USER=iotedu
MYSQL_PASSWORD=${DBPASS}
MYSQL_DB=iotedu
MYSQL_HOST=db

# === Sessão (gerado automaticamente) ===
SESSION_SECRET_KEY=${SESSION}

# === Superusuários (vírgula-separado, lowercase) ===
SUPERUSER_ACCESS=admin@${DOMAIN}

# === Google OAuth — preenche se for usar ===
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GOOGLE_REDIRECT_URI=https://${DOMAIN}/api/auth/google/callback

# === Keycloak IdP IoTEdu — preenche se for usar ===
IDP_IOTEDU_DISCOVERY_URL=
IDP_IOTEDU_CLIENT_ID=iotedu-web
IDP_IOTEDU_CLIENT_SECRET=
IDP_IOTEDU_REDIRECT_URI=https://${DOMAIN}/api/auth/iotedu/callback
IDP_IOTEDU_POST_LOGOUT_URI=https://${DOMAIN}/

# === Keycloak IdP AnonShield — preenche se for usar ===
IDP_ANONSHIELD_DISCOVERY_URL=
IDP_ANONSHIELD_CLIENT_ID=iotedu-web
IDP_ANONSHIELD_CLIENT_SECRET=
IDP_ANONSHIELD_REDIRECT_URI=https://${DOMAIN}/api/auth/anonshield/callback
IDP_ANONSHIELD_POST_LOGOUT_URI=https://${DOMAIN}/

# === IDS / SSE ===
IDS_SSE_TLS_VERIFY=false
# PFSENSE_API_URL=
# PFSENSE_API_KEY=
EOF
    chmod 600 "$ENV_FILE"
else
    log ".env já existe em $ENV_FILE — não toquei"
fi

# --- 6. Vhost no Caddyfile (só no modo host) -----------------------------
CADDYFILE=/etc/caddy/Caddyfile
if [ "$CADDY_MODE" = "host" ]; then
    if ! sudo grep -q "^${DOMAIN} {" "$CADDYFILE" 2>/dev/null; then
        log "adicionando vhost ${DOMAIN} em $CADDYFILE"
        sudo tee -a "$CADDYFILE" >/dev/null <<EOF

${DOMAIN} {
    handle /api/* { reverse_proxy localhost:8000 }
    handle /auth/* { reverse_proxy localhost:8000 }
    handle /docs* { reverse_proxy localhost:8000 }
    handle /openapi.json { reverse_proxy localhost:8000 }
    handle /health { reverse_proxy localhost:8000 }
    handle { reverse_proxy localhost:3000 }
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
}
EOF
        sudo caddy validate --config "$CADDYFILE"
        sudo systemctl reload caddy
        log "Caddy recarregado — cert TLS sai automaticamente quando DNS apontar"
    else
        log "vhost ${DOMAIN} já existe no Caddyfile"
    fi
fi

# --- 7. Alias de deploy --------------------------------------------------
# Modo container: passa CADDY_DOMAIN pra lib subir Caddy próprio + não
# publica portas no host (Caddy proxia via rede docker, por nome).
if [ "$CADDY_MODE" = "container" ]; then
    DEPLOY_ENV="CADDY_DOMAIN=${DOMAIN} PUBLISH_HOST_PORTS=no HEALTH_URL=https://${DOMAIN}/health PROJECT=${PROJECT} DB_VOLUME=${PROJECT}-db-data REPO_DIR=$REPO_DIR"
else
    DEPLOY_ENV="HEALTH_URL=https://${DOMAIN}/health PROJECT=${PROJECT} DB_VOLUME=${PROJECT}-db-data REPO_DIR=$REPO_DIR"
fi
ALIAS_LINE="alias iotedu-deploy='cd $REPO_DIR && git pull && $DEPLOY_ENV bash scripts/guasca-deploy.sh'"
if ! grep -qF "iotedu-deploy=" "$HOME/.bashrc" 2>/dev/null; then
    echo "$ALIAS_LINE" >> "$HOME/.bashrc"
    log "alias 'iotedu-deploy' adicionado em ~/.bashrc"
fi

# --- 8. Próximos passos --------------------------------------------------
cat <<EOF

============================================================
bootstrap completo
============================================================
Domínio:   $DOMAIN
Repo:      $REPO_DIR
Project:   $PROJECT
Volume DB: ${PROJECT}-db-data
Caddy:     ${CADDY_MODE} ($([ "$CADDY_MODE" = "host" ] && echo "systemd nativo" || echo "container gerenciado pelo deploy"))

Próximos passos (NÃO automatizáveis):

1. Aponta o DNS:
   $DOMAIN → IP $(curl -s --max-time 3 ifconfig.me 2>/dev/null || echo "<ip-deste-host>")

2. Edita $ENV_FILE e preenche:
   - GOOGLE_CLIENT_ID + GOOGLE_CLIENT_SECRET (se for usar Google)
   - IDP_*_DISCOVERY_URL + IDP_*_CLIENT_SECRET (se for usar Keycloak)
   - SUPERUSER_ACCESS (emails de admins)

3. Configura redirect URIs nos providers OAuth:
   - Google Cloud Console: https://$DOMAIN/api/auth/google/callback
   - Keycloak iotedu:        https://$DOMAIN/api/auth/iotedu/callback
   - Keycloak anonshield:    https://$DOMAIN/api/auth/anonshield/callback

4. Roda o deploy:
   newgrp docker     # se acabou de instalar docker
   source ~/.bashrc  # carrega o alias
   iotedu-deploy

A app vai estar em https://$DOMAIN em ~5 min.
Re-rode esse bootstrap quando quiser — é idempotente.
============================================================
EOF
