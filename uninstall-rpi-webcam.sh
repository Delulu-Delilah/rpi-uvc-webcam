#!/bin/bash
# ============================================================================
# Raspberry Pi USB Webcam — Uninstaller v3.0
# ============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'
info() { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()   { echo -e "${GREEN}[ OK ]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }

[[ $(id -u) -eq 0 ]] && { echo -e "${RED}[FAIL]${NC} Do NOT run as root."; exit 1; }

GADGET_SCRIPT="${HOME}/.rpi-uvc-gadget.sh"
UVC_DIR="${HOME}/uvc-gadget"
BOOT_CONFIG="/boot/firmware/config.txt"
[[ ! -f "$BOOT_CONFIG" ]] && BOOT_CONFIG="/boot/config.txt"

echo ""
echo -e "${RED}═══ Pi Webcam — Uninstaller ═══${NC}"
echo ""
echo "Will remove:"
echo "  • systemd services (usb, network, update timer)"
echo "  • pi-webcam CLI"
echo "  • MJPEG server + auto-update scripts"
echo "  • SSH login banner"
echo "  • Configuration (/etc/rpi-webcam.conf)"
echo "  • Gadget script + uvc-gadget build"
echo "  • dwc2 overlay from config.txt"
echo ""
read -rp "Continue? [y/N] " yn
[[ ! "$yn" =~ ^[Yy] ]] && { info "Aborted."; exit 0; }

# Services
for svc in rpi-uvc-gadget.service rpi-webcam-network.service rpi-webcam-update.service rpi-webcam-update.timer rpi-webcam-timelapse.service; do
    if systemctl list-unit-files "$svc" &>/dev/null; then
        sudo systemctl stop "$svc" 2>/dev/null || true
        sudo systemctl disable "$svc" 2>/dev/null || true
        sudo rm -f "/etc/systemd/system/$svc"
    fi
done
sudo systemctl daemon-reload
ok "Services removed."

# CLI + scripts
sudo rm -f /usr/local/bin/pi-webcam
sudo rm -rf /usr/local/lib/rpi-webcam
ok "CLI and scripts removed."

# Config + MOTD + gadget script
sudo rm -f /etc/rpi-webcam.conf
sudo rm -f /etc/profile.d/rpi-webcam-status.sh
rm -f "$GADGET_SCRIPT"
ok "Config, banner, gadget script removed."

# rc.local cleanup (legacy)
RC="/etc/rc.local"
[[ -f "$RC" ]] && grep -qF ".rpi-uvc-gadget.sh" "$RC" && sudo sed -i '\|\.rpi-uvc-gadget\.sh|d' "$RC"

# uvc-gadget binaries
if [[ -d "${UVC_DIR}/build" ]]; then
    sudo ninja -C "${UVC_DIR}/build" uninstall 2>/dev/null || {
        sudo rm -f /usr/local/bin/uvc-gadget
        sudo rm -f /usr/local/lib/aarch64-linux-gnu/libuvcgadget.so*
        sudo rm -rf /usr/local/include/uvcgadget
        sudo rm -f /usr/local/lib/aarch64-linux-gnu/pkgconfig/uvcgadget.pc
    }
    sudo ldconfig
fi
ok "uvc-gadget binaries removed."

# Source directory
[[ -d "$UVC_DIR" ]] && rm -rf "$UVC_DIR" && ok "Source removed."

# dwc2 overlay
DWC2="dtoverlay=dwc2,dr_mode=otg"
if grep -qF "$DWC2" "$BOOT_CONFIG" 2>/dev/null; then
    sudo sed -i "\|${DWC2}|d" "$BOOT_CONFIG"
    ok "dwc2 overlay removed."
fi

echo ""
echo -e "${GREEN}  Uninstall complete!${NC}"
echo -e "  Dependencies (git, meson, etc.) were not removed."
echo ""
read -rp "Reboot now? [y/N] " yn
[[ "$yn" =~ ^[Yy] ]] && sudo reboot || info "Reboot to fully clear dwc2 overlay."
