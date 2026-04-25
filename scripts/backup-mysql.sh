#!/usr/bin/env bash
# Backup diário do MySQL via docker exec. Roda como cron job
# instalado pelo deploy script. Retém últimos 7 dias por padrão.
#
# Vars (override via env):
#   MYSQL_CONTAINER  nome do container do db (ex: iotedu-anonshield-db-1)
#   BACKUP_DIR       destino dos dumps (default: $HOME/backups/mysql)
#   RETAIN_DAYS      quantos dias manter (default: 7)
set -euo pipefail

CONTAINER="${MYSQL_CONTAINER:-$(docker ps --filter 'name=-db' --format '{{.Names}}' | head -1)}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/backups/mysql}"
RETAIN_DAYS="${RETAIN_DAYS:-7}"

if [ -z "$CONTAINER" ]; then
    echo "$(date -Is) backup: no db container found" >&2
    exit 1
fi

mkdir -p "$BACKUP_DIR"
TS=$(date +%Y%m%d-%H%M%S)
OUT="$BACKUP_DIR/${CONTAINER}-${TS}.sql.gz"

docker exec -e MYSQL_PWD="$(docker exec "$CONTAINER" printenv MYSQL_ROOT_PASSWORD)" \
    "$CONTAINER" mysqldump -uroot --all-databases --single-transaction \
    --quick --lock-tables=false 2>/dev/null \
    | gzip > "$OUT.tmp"
mv "$OUT.tmp" "$OUT"

find "$BACKUP_DIR" -name '*.sql.gz' -mtime +"$RETAIN_DAYS" -delete

SIZE=$(du -h "$OUT" | cut -f1)
echo "$(date -Is) backup ok: $OUT ($SIZE)"
