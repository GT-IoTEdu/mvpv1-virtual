#!/bin/bash

# Configurações de caminhos - Ajuste se necessário
SNORT_BIN="/opt/snort3/bin/snort"
CONFIG_FILE="/opt/snort3/etc/snort/snort.lua"
LOG_DIR="/opt/snort3/logs"

# Define interface padrão se não fornecida
INTERFACE=${1:-ens33}
SNORT_CHECKSUM_MODE=${SNORT_CHECKSUM_MODE:-none}

# Remove o primeiro argumento para passar o resto para o snort
shift || true

echo "=========================================="
echo "        Snort3 Detector Iniciando"
echo "=========================================="
echo "Interface: $INTERFACE"
echo "Config:    $CONFIG_FILE"
echo "Logs:      $LOG_DIR"
echo "=========================================="

# 1. Verifica se o binário do Snort existe
if [ ! -f "$SNORT_BIN" ]; then
    echo "ERRO: Binário do Snort não encontrado em $SNORT_BIN"
    exit 1
fi

# 2. Verifica se a interface existe
if ! ip link show "$INTERFACE" > /dev/null 2>&1; then
    echo "ERRO: Interface '$INTERFACE' não encontrada!"
    echo "Interfaces disponíveis:"
    ip link show | grep -E '^[0-9]+:' | awk '{print $2}' | tr -d ':'
    exit 1
fi

# 3. Testa a configuração antes de iniciar
echo "Testando configuração do Snort3..."
if ! "$SNORT_BIN" -c "$CONFIG_FILE" -T; then
    echo "------------------------------------------"
    echo "ERRO: Configuração do Snort3 inválida!"
    exit 1
fi

echo "Configuração OK! Iniciando Snort3..."
echo "Para parar: Ctrl+C"
echo "Checksum mode: $SNORT_CHECKSUM_MODE"
echo "=========================================="


# Inicia o Snort3 com os parâmetros fornecidos
exec snort -c /opt/snort3/etc/snort/snort.lua -i "$INTERFACE" -k "$SNORT_CHECKSUM_MODE" -v -l /opt/snort3/logs "$@"

# 4. Inicia o Snort3 (usando sudo para garantir permissões)
"$SNORT_BIN" -c "$CONFIG_FILE" -i "$INTERFACE" -v -l "$LOG_DIR" "$@"

