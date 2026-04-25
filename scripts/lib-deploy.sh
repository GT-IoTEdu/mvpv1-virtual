#!/usr/bin/env bash
# Funções compartilhadas pelos deploys sem docker compose.
# Cada host (a9, guasca) seta as variáveis e chama as funções daqui.
#
# Variáveis esperadas (setadas pelo script chamador antes de `source`):
#   REPO_DIR              — caminho do checkout no host
#   PROJECT               — prefixo dos nomes de container e da rede
#   DB_VOLUME             — nome do volume nomeado do MySQL (preserva dados)
#   DB_PASSWORDS          — env_file com MYSQL_* (mesmo arquivo usado pelo backend)
#   PUBLISH_HOST_PORTS    — "yes"|"no" — se publica backend/frontend em 127.0.0.1
#   CADDY_CONTAINER       — opcional, nome do container Caddy a conectar à rede
#   HEALTH_URL            — URL https para sondar /health
#   IDS_ENABLED           — "auto"|"yes"|"no" — auto detecta bridge-tap

set -euo pipefail

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

# --- rede ---------------------------------------------------------------
ensure_network() {
    local net="${PROJECT}-net"
    if ! docker network inspect "$net" >/dev/null 2>&1; then
        docker network create "$net" >/dev/null
        log "rede criada: $net"
    fi
    NET="$net"
}

# --- build --------------------------------------------------------------
# Imagens da app (backend/frontend/sse) sempre rebuild — código muda a cada deploy
# e o BuildKit aproveita layer cache. Imagens de IDS (zeek/suricata/snort) levam
# muito (zeek é particularmente caro) e mudam pouco; só rebuild se a imagem não
# existir ou se IDS_FORCE_BUILD=yes for passado.
build_app_image() {
    local svc="$1" ctx="$2"
    log "build $svc"
    docker build -q -t "${PROJECT}/${svc}:latest" "$ctx" >/dev/null
}

build_ids_image() {
    local svc="$1"
    local ctx="$2"
    local tag="${PROJECT}/${svc}:latest"
    if [ "${IDS_FORCE_BUILD:-no}" != "yes" ] && docker image inspect "$tag" >/dev/null 2>&1; then
        log "$svc: imagem já existe, pulando build (IDS_FORCE_BUILD=yes pra forçar)"
        return
    fi
    log "build $svc (lento)"
    docker build -q -t "$tag" "$ctx" >/dev/null
}

build_images() {
    build_app_image backend  "$REPO_DIR/backend"
    build_app_image frontend "$REPO_DIR/frontend"
    build_app_image sse      "$REPO_DIR/ids/ids_log_monitor"
    if [ "$IDS_ENABLED" = "yes" ]; then
        build_ids_image zeek     "$REPO_DIR/ids/implementation/zeek"
        build_ids_image suricata "$REPO_DIR/ids/implementation/suricata"
        build_ids_image snort    "$REPO_DIR/ids/implementation/snort"
    fi
}

# --- containers de aplicação --------------------------------------------
ensure_db() {
    local name="${PROJECT}-db-1"
    if docker inspect "$name" >/dev/null 2>&1; then
        local status on_net
        status=$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || echo unknown)
        if docker inspect -f '{{range $k,$_ := .NetworkSettings.Networks}}{{$k}}
{{end}}' "$name" | grep -qx "$NET"; then
            on_net=yes
        else
            on_net=no
        fi
        if [ "$status" = "running" ] && [ "$on_net" = "yes" ]; then
            log "db: $name já roda em $NET, mantém estado"
            return
        fi
        log "db: $name (status=$status, em_$NET=$on_net) — recriando (volume $DB_VOLUME preservado)"
        docker rm -f "$name" >/dev/null
    fi
    # Lê MYSQL_* do env_file e mapeia para os nomes esperados pela imagem mysql:8
    # (a app usa MYSQL_DB; a imagem oficial espera MYSQL_DATABASE).
    set -a; . "$DB_PASSWORDS"; set +a
    : "${MYSQL_ROOT_PASSWORD:?defina MYSQL_ROOT_PASSWORD em $DB_PASSWORDS}"
    : "${MYSQL_USER:?defina MYSQL_USER em $DB_PASSWORDS}"
    : "${MYSQL_PASSWORD:?defina MYSQL_PASSWORD em $DB_PASSWORDS}"
    : "${MYSQL_DB:?defina MYSQL_DB em $DB_PASSWORDS}"

    log "db: criando $name (volume $DB_VOLUME)"
    docker run -d \
        --name "$name" \
        --network "$NET" --network-alias db \
        --restart unless-stopped \
        -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
        -e MYSQL_DATABASE="$MYSQL_DB" \
        -e MYSQL_USER="$MYSQL_USER" \
        -e MYSQL_PASSWORD="$MYSQL_PASSWORD" \
        -v "$DB_VOLUME:/var/lib/mysql" \
        --health-cmd='mysqladmin ping -h localhost -uroot -p"$MYSQL_ROOT_PASSWORD" --silent || exit 1' \
        --health-interval=5s --health-timeout=3s --health-retries=20 --health-start-period=30s \
        mysql:8 >/dev/null
}

wait_db_healthy() {
    local name="${PROJECT}-db-1"
    log "aguardando MySQL ficar saudável"
    for _ in $(seq 1 60); do
        local s
        s=$(docker inspect -f '{{.State.Health.Status}}' "$name" 2>/dev/null || echo none)
        [ "$s" = "healthy" ] && { log "db: healthy"; return 0; }
        sleep 2
    done
    log "ERRO: MySQL não ficou healthy"
    docker logs --tail=30 "$name" || true
    return 1
}

run_app_container() {
    local svc="$1" image="$2" port_int="$3" port_host="${4:-$3}"
    local name="${PROJECT}-${svc}-1"
    docker rm -f "$name" >/dev/null 2>&1 || true
    local args=(
        -d
        --name "$name"
        --network "$NET" --network-alias "$svc"
        --restart unless-stopped
        --env-file "$REPO_DIR/backend/.env"
        --add-host "host.docker.internal:host-gateway"
    )
    if [ "$PUBLISH_HOST_PORTS" = "yes" ]; then
        args+=(-p "127.0.0.1:${port_host}:${port_int}")
    fi
    docker run "${args[@]}" "$image" >/dev/null
    if [ "$PUBLISH_HOST_PORTS" = "yes" ]; then
        log "$svc: $name (host 127.0.0.1:${port_host} → container :${port_int})"
    else
        log "$svc: $name (porta interna ${port_int})"
    fi
}

run_sse() {
    local name="${PROJECT}-sse_server-1"
    docker rm -f "$name" >/dev/null 2>&1 || true
    docker run -d \
        --name "$name" \
        --network "$NET" --network-alias sse_server \
        --restart unless-stopped \
        -v "$REPO_DIR/ids/logs:/ids/logs:ro" \
        "${PROJECT}/sse:latest" >/dev/null
    log "sse_server: $name"
}

# --- IDS (host network, privileged) -------------------------------------
run_ids() {
    local zeek="${PROJECT}-zeek-1"
    local sur="${PROJECT}-suricata_ids-1"
    local sno="${PROJECT}-snort_ids-1"

    # Sempre limpa containers antigos de IDS — se IDS for "no" agora
    # mas estavam rodando antes, eles ficam restartando sem bridge-tap.
    docker rm -f "$zeek" "$sur" "$sno" >/dev/null 2>&1 || true

    [ "$IDS_ENABLED" = "yes" ] || { log "IDS desativado (containers antigos removidos se houvesse)"; return 0; }

    log "zeek: $zeek"
    docker run -d --name "$zeek" \
        --network host --privileged \
        --cap-add NET_RAW --cap-add NET_ADMIN \
        -e ZEEK_INTERFACE=bridge-tap \
        -v "$REPO_DIR/ids/logs/logs_zeek/:/usr/local/zeek/spool/zeek" \
        -v "$REPO_DIR/ids/rules/site_zeek:/usr/local/zeek/share/zeek/site" \
        -v /etc/localtime:/etc/localtime:ro \
        --restart unless-stopped \
        "${PROJECT}/zeek:latest" >/dev/null

    log "suricata: $sur"
    docker run -d --name "$sur" \
        --network host --privileged \
        -v "$REPO_DIR/ids/rules/rules_suricata:/var/lib/suricata/rules" \
        -v "$REPO_DIR/ids/logs/logs_suricata:/var/log/suricata" \
        --restart unless-stopped \
        "${PROJECT}/suricata:latest" bridge-tap >/dev/null

    log "snort: $sno"
    docker run -d --name "$sno" \
        --network host --privileged \
        -v "$REPO_DIR/ids/rules/rules_snort:/opt/snort3/etc/snort/rules" \
        -v "$REPO_DIR/ids/logs/logs_snort:/opt/snort3/logs" \
        --restart unless-stopped \
        "${PROJECT}/snort:latest" bridge-tap -m 0022 >/dev/null
}

# --- Caddy (em container, no a9) ----------------------------------------
# Modo "attach": já existe um Caddy gerenciado fora do nosso projeto
# (ex.: web-caddy-1 no a9 que serve outros sites). A gente só conecta
# ele à nossa rede pra que resolva os containers da app por nome.
attach_caddy() {
    [ -n "${CADDY_CONTAINER:-}" ] || return 0
    if ! docker inspect "$CADDY_CONTAINER" >/dev/null 2>&1; then
        log "aviso: container Caddy '$CADDY_CONTAINER' não existe — pulei attach"
        return 0
    fi
    if docker inspect "$CADDY_CONTAINER" \
        --format '{{range $k,$_ := .NetworkSettings.Networks}}{{$k}}{{println}}{{end}}' \
        | grep -qx "$NET"; then
        return 0
    fi
    log "conectando $CADDY_CONTAINER à rede $NET"
    docker network connect "$NET" "$CADDY_CONTAINER"
}

# Modo "owned": a gente sobe um Caddy próprio em container, com
# Caddyfile gerado a partir de $CADDY_DOMAIN. Usado em hosts que NÃO
# têm Caddy instalado nativamente. Caddy entra na mesma rede docker do
# projeto e proxia por nome (backend, frontend) — backend/frontend
# nesses casos não publicam porta no host.
ensure_caddy_container() {
    [ -n "${CADDY_DOMAIN:-}" ] || return 0
    local name="${PROJECT}-caddy-1"
    local conf_dir="$REPO_DIR/.caddy"
    local conf_file="$conf_dir/Caddyfile"

    mkdir -p "$conf_dir"
    cat > "$conf_file" <<EOF
${CADDY_DOMAIN} {
    handle /api/*       { reverse_proxy backend:8000 }
    handle /auth/*      { reverse_proxy backend:8000 }
    handle /docs*       { reverse_proxy backend:8000 }
    handle /openapi.json { reverse_proxy backend:8000 }
    handle /health      { reverse_proxy backend:8000 }
    handle              { reverse_proxy frontend:3000 }
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
}
EOF
    docker rm -f "$name" >/dev/null 2>&1 || true
    log "subindo Caddy próprio em container ($CADDY_DOMAIN, ports 80/443)"
    docker run -d --name "$name" \
        --network "$NET" \
        --restart unless-stopped \
        -p 80:80 -p 443:443 -p 443:443/udp \
        -v "$conf_file:/etc/caddy/Caddyfile:ro" \
        -v "${PROJECT}-caddy-data:/data" \
        -v "${PROJECT}-caddy-config:/config" \
        caddy:2-alpine >/dev/null
}

# --- backup automático --------------------------------------------------
ensure_backup_cron() {
    local line="0 3 * * * MYSQL_CONTAINER=${PROJECT}-db-1 $REPO_DIR/scripts/backup-mysql.sh >> $REPO_DIR/.backup.log 2>&1"
    if ! crontab -l 2>/dev/null | grep -qF "$REPO_DIR/scripts/backup-mysql.sh"; then
        (crontab -l 2>/dev/null; echo "$line") | crontab -
        log "cron de backup do MySQL instalado"
    fi
}

# --- saúde + smoke ------------------------------------------------------
# Probe DIRETO no container do backend pela rede docker — bypassa DNS público,
# Caddy e TLS. Usa o IP interno do container. Garante apenas que backend +
# DB estão de pé. Cobertura end-to-end (Caddy + cert + DNS) fica no smoke-test.
# 90 tentativas × 2s = 3min, mais que suficiente pra migrations + uvicorn.
wait_health() {
    local name="${PROJECT}-backend-1"
    local ip
    ip=$(docker inspect -f "{{(index .NetworkSettings.Networks \"$NET\").IPAddress}}" "$name" 2>/dev/null || echo "")
    if [ -z "$ip" ]; then
        log "ERRO: container $name sem IP em $NET"
        return 1
    fi
    local url="http://${ip}:8000/health"
    log "sondando $url (interno, via $NET)"
    for _ in $(seq 1 90); do
        if curl -fsS --max-time 5 "$url" >/dev/null 2>&1; then
            log "health: OK"
            return 0
        fi
        sleep 2
    done
    log "ERRO: backend não respondeu 200 em 3min"
    docker ps --format 'table {{.Names}}\t{{.Status}}' | grep "${PROJECT}-" || true
    docker logs --tail=40 "$name" || true
    return 1
}

run_smoke_test() {
    local base="${HEALTH_URL%/health}"
    bash "$REPO_DIR/scripts/smoke-test.sh" "$base"
}

# --- entrypoint ---------------------------------------------------------
deploy() {
    cd "$REPO_DIR"

    # Lock: espera até 10min se outro deploy estiver rodando — evita falha
    # falsa no CI quando deploys empilham (manual + push + dispatch).
    exec 9>"$REPO_DIR/.deploy.lock"
    flock -w 600 9 || { echo "deploy bloqueado: outro deploy não liberou em 10min" >&2; exit 1; }

    case "$IDS_ENABLED" in
        auto) ip link show bridge-tap >/dev/null 2>&1 && IDS_ENABLED=yes || IDS_ENABLED=no ;;
        yes|no) ;;
        *) echo "IDS_ENABLED inválido: $IDS_ENABLED" >&2; exit 1 ;;
    esac
    log "IDS_ENABLED=$IDS_ENABLED"

    ensure_backup_cron
    ensure_network
    attach_caddy             # modo "Caddy externo já existente" (a9)
    build_images

    ensure_db
    wait_db_healthy

    run_app_container backend  "${PROJECT}/backend:latest"  8000 "${HOST_PORT_BACKEND:-8000}"
    run_app_container frontend "${PROJECT}/frontend:latest" 3000 "${HOST_PORT_FRONTEND:-3000}"
    run_sse
    run_ids
    ensure_caddy_container   # modo "Caddy próprio em container" (hosts sem Caddy nativo)

    docker image prune -f >/dev/null

    wait_health
    run_smoke_test
}
