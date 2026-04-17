#!/bin/bash
set -e

CONFIG_FILE="/etc/suricata/suricata.yaml"

IFACE="${1:-${SURICATA_IFACE:-ens33}}"
shift || true
EXTRA_ARGS="$SURICATA_ARGS $*"
HOME_NET_VAL="${SURICATA_HOME_NET:-any}"

echo "=========================================="
echo "        Suricata IDS Iniciando"
echo "=========================================="
echo "Interface: ${IFACE}"
echo "HOME_NET:  ${HOME_NET_VAL}"
echo "Config:    ${CONFIG_FILE}"
echo "Rules:     /var/lib/suricata/rules/"
echo "Logs:      /var/log/suricata/"
echo "Args:      ${EXTRA_ARGS}"
echo "=========================================="

# Verifica interface se não for 'any'
if [ "${IFACE}" != "any" ] && ! ip link show "$IFACE" > /dev/null 2>&1; then
  echo "[ERRO] Interface '$IFACE' não encontrada!"
  echo "Interfaces disponíveis:"
  ip link show | grep -E '^[0-9]+:' | awk '{print $2}' | tr -d ':'
  exit 1
fi

# Atualiza YAML com HOME_NET, EXTERNAL_NET e interfaces
export IFACE_ENV="$IFACE"
export HOME_NET_ENV="$HOME_NET_VAL"

python3 -c '
import os
import sys

try:
    import yaml
except ImportError:
    print("[ERRO] PyYAML não instalado!", file=sys.stderr)
    sys.exit(1)

cfg_path = "/etc/suricata/suricata.yaml"
iface = os.environ.get("IFACE_ENV", "enp0s3")
home_net = os.environ.get("HOME_NET_ENV", "any")

# Lê o arquivo linha por linha
with open(cfg_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

# Remove os cabeçalhos YAML que confundem o PyYAML
clean_lines = [line for line in lines if line.strip() not in ["%YAML 1.1", "YAML 1.1", "---"]]
clean_content = "".join(clean_lines)

# Parse do YAML limpo
try:
    cfg = yaml.safe_load(clean_content)
except Exception as e:
    print(f"[ERRO] PyYAML falhou: {e}", file=sys.stderr)
    sys.exit(1)

if cfg is None:
    print("[ERRO] Falha ao parsear YAML!", file=sys.stderr)
    sys.exit(1)

# Atualiza HOME_NET e EXTERNAL_NET
try:
    if "vars" not in cfg:
        cfg["vars"] = {}
    if "address-groups" not in cfg["vars"]:
        cfg["vars"]["address-groups"] = {}
    
    cfg["vars"]["address-groups"]["HOME_NET"] = home_net
    cfg["vars"]["address-groups"]["EXTERNAL_NET"] = f"!{home_net}" if home_net != "any" else "any"
except Exception as e:
    print(f"[AVISO] Erro ao atualizar vars: {e}", file=sys.stderr)

# Atualiza interfaces af-packet e pcap
for interface_type in ["af-packet", "pcap"]:
    try:
        if interface_type in cfg and isinstance(cfg[interface_type], list):
            for entry in cfg[interface_type]:
                if isinstance(entry, dict) and "interface" in entry:
                    if entry["interface"] not in [None, "default"]:
                        entry["interface"] = iface
    except Exception as e:
        print(f"[AVISO] Erro ao atualizar {interface_type}: {e}", file=sys.stderr)

# Salva YAML forçando o cabeçalho exigido pelo Suricata
with open(cfg_path, "w", encoding="utf-8") as f:
    f.write("%YAML 1.1\n---\n\n")
    yaml.safe_dump(
        cfg,
        f,
        default_flow_style=False,
        sort_keys=False,
        allow_unicode=True,
        width=120
    )

print(f"[INFO] YAML atualizado: HOME_NET={home_net}, interface={iface}", file=sys.stderr)
'

# Testa configuração
echo "[INFO] Testando configuração..."
if ! suricata -T -c "$CONFIG_FILE" > /tmp/suricata_test.log 2>&1; then
  echo "[ERRO] Configuração inválida:"
  tail -30 /tmp/suricata_test.log
fi

echo "[OK] Configuração válida."

# Inicia Suricata
echo "[INFO] Iniciando Suricata (Ctrl+C para parar)..."
exec suricata -c "$CONFIG_FILE" -i "$IFACE" $EXTRA_ARGSc
