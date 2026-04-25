#!/usr/bin/env bash
# One-shot host bootstrap for the iotedu-anonshield deploy.
#
# Sets up everything that requires root (vbox kernel modules, bridge-tap,
# tap0, systemd units for boot persistence, pfSense OVA download/import,
# VM auto-start). Idempotent: safe to re-run after kernel/host upgrades
# or to recover state.
#
# Usage:
#     sudo bash scripts/setup-host.sh
#
# Override via env:
#     DEPLOY_USER       (default: invoking sudo user)
#     PFSENSE_DIR       (default: /var/lib/iotedu-pfsense)
#     OVA_URL           (default: Zenodo record 19608142)
#     VM_NAME           (default: iotedu-pfsense)
#     SKIP_VM=1         to skip OVA download/import/start (only set up
#                       modules, bridge-tap and systemd units)

set -euo pipefail

DEPLOY_USER="${DEPLOY_USER:-${SUDO_USER:-$(logname 2>/dev/null || true)}}"
PFSENSE_DIR="${PFSENSE_DIR:-/var/lib/iotedu-pfsense}"
OVA_URL="${OVA_URL:-https://zenodo.org/api/records/19608142/files/pfsense-virtualizacao.ova/content}"
VM_NAME="${VM_NAME:-iotedu-pfsense}"
SKIP_VM="${SKIP_VM:-0}"

[ "$EUID" -eq 0 ] || { echo "must be run as root (sudo bash $0)" >&2; exit 1; }
[ -n "$DEPLOY_USER" ] || { echo "could not infer DEPLOY_USER; export DEPLOY_USER=..." >&2; exit 1; }

log() { printf '\033[1;32m[setup-host]\033[0m %s\n' "$*"; }

#--- 1. Kernel modules + bridge persistence (systemd) ----------------------

log "installing systemd unit iotedu-bridge-tap.service"
cat >/etc/systemd/system/iotedu-bridge-tap.service <<'UNIT'
[Unit]
Description=iotedu bridge-tap + tap0 + vbox modules
After=network-online.target
Before=docker.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=-/sbin/modprobe vboxdrv
ExecStartPre=-/sbin/modprobe vboxnetflt
ExecStartPre=-/sbin/modprobe vboxnetadp
ExecStart=/bin/sh -c '\
ip link show bridge-tap >/dev/null 2>&1 || ip link add bridge-tap type bridge; \
ip link set bridge-tap up; \
ip link show tap0 >/dev/null 2>&1 || ip tuntap add dev tap0 mode tap; \
ip link set tap0 master bridge-tap; \
ip link set tap0 up'
ExecStop=-/bin/sh -c 'ip link del tap0 2>/dev/null; ip link del bridge-tap 2>/dev/null; true'

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now iotedu-bridge-tap.service
log "iotedu-bridge-tap.service active"

if [ "$SKIP_VM" = "1" ]; then
    log "SKIP_VM=1 — done."
    exit 0
fi

#--- 2. Download OVA (idempotent) ------------------------------------------

mkdir -p "$PFSENSE_DIR"
chown "$DEPLOY_USER":"$DEPLOY_USER" "$PFSENSE_DIR"
OVA_FILE="$PFSENSE_DIR/pfsense.ova"
if [ ! -s "$OVA_FILE" ]; then
    log "downloading OVA from $OVA_URL"
    sudo -u "$DEPLOY_USER" curl -fL --progress-bar -o "$OVA_FILE.tmp" "$OVA_URL"
    sudo -u "$DEPLOY_USER" mv "$OVA_FILE.tmp" "$OVA_FILE"
else
    log "OVA already present at $OVA_FILE"
fi

#--- 3. Import VM (idempotent) ---------------------------------------------

if ! VBoxManage list vms 2>/dev/null | grep -qE "^\"$VM_NAME\""; then
    log "importing OVA as VM '$VM_NAME'"
    mkdir -p "$PFSENSE_DIR/vms"
    VBoxManage import "$OVA_FILE" --vsys 0 --vmname "$VM_NAME" \
        --basefolder "$PFSENSE_DIR/vms"
    VBoxManage modifyvm "$VM_NAME" \
        --nic1 bridged --bridgeadapter1 bridge-tap --nicpromisc1 allow-all \
        --rtcuseutc on
else
    log "VM '$VM_NAME' already imported"
fi

#--- 4. systemd unit for VM autostart -------------------------------------

log "installing systemd unit iotedu-pfsense.service"
cat >/etc/systemd/system/iotedu-pfsense.service <<UNIT
[Unit]
Description=iotedu pfSense VM
Requires=iotedu-bridge-tap.service
After=iotedu-bridge-tap.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/VBoxManage startvm $VM_NAME --type headless
ExecStop=/usr/bin/VBoxManage controlvm $VM_NAME acpipowerbutton

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
if systemctl enable --now iotedu-pfsense.service; then
    log "iotedu-pfsense.service active"
else
    log "ERRO: iotedu-pfsense.service falhou ao iniciar — verifique:"
    log "  sudo systemctl status iotedu-pfsense.service --no-pager -l"
    log "  sudo journalctl -xeu iotedu-pfsense.service --no-pager | tail -30"
    log "Causas comuns: memória insuficiente (VM pede 9GB), NICs 2/3 bridgeados"
    log "em interface inexistente (corrige com: VBoxManage modifyvm $VM_NAME --nic2 none --nic3 none),"
    log "vboxdrv não carregado (modprobe vboxdrv) ou Secure Boot bloqueando módulos."
    exit 1
fi

#--- 5. Summary ------------------------------------------------------------

cat <<EOF

============================================================
setup-host complete
============================================================
- bridge-tap + tap0       : up, persisted at boot
- vboxdrv kernel modules  : loaded, persisted at boot
- pfSense VM '$VM_NAME'   : imported, started, persisted at boot
- OVA path                : $OVA_FILE
- VM directory            : $PFSENSE_DIR/vms

next steps (one-time, manual via pfSense console or webui):
  1. open pfSense console:   VBoxManage controlvm $VM_NAME poweroff
                             VBoxManage startvm $VM_NAME --type sdl
     (or attach a remote console)
  2. configure WAN/LAN, set admin password, generate API key
  3. add PFSENSE_API_URL and PFSENSE_API_KEY to backend/.env on the
     deploy server
  4. CI/CD on push will pick up the new env (no rebuild needed)

re-run this script anytime to repair state (idempotent).
EOF
