#!/bin/bash
# ============================================================================
# Raspberry Pi USB Webcam (UVC Gadget) — Uninstaller
# Reverses everything done by install-rpi-webcam.sh
#
# Run on your Pi:
#   curl -sSL https://raw.githubusercontent.com/Delulu-Delilah/rpi-uvc-webcam/main/uninstall-rpi-webcam.sh | bash
# ============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }

[[ $(id -u) -eq 0 ]] && fail "Do NOT run this script as root. Run as your normal user (sudo is used internally)."

CURRENT_USER=$(whoami)
GADGET_SCRIPT="${HOME}/.rpi-uvc-gadget.sh"
SERVICE_FILE="/etc/systemd/system/rpi-uvc-gadget.service"
UVC_DIR="${HOME}/uvc-gadget"
BOOT_CONFIG="/boot/firmware/config.txt"
[[ ! -f "$BOOT_CONFIG" ]] && BOOT_CONFIG="/boot/config.txt"
DWC2_LINE="dtoverlay=dwc2,dr_mode=otg"

echo ""
echo -e "${RED}============================================${NC}"
echo -e "${RED}  Raspberry Pi UVC Webcam — Uninstaller${NC}"
echo -e "${RED}============================================${NC}"
echo ""
echo "This will remove:"
echo "  • systemd service:  ${SERVICE_FILE}"
echo "  • gadget script:    ${GADGET_SCRIPT}"
echo "  • uvc-gadget build: ${UVC_DIR}"
echo "  • installed binaries (uvc-gadget, libuvcgadget)"
echo "  • dwc2 overlay line from ${BOOT_CONFIG}"
echo ""
read -rp "Continue? [y/N] " yn
case "$yn" in
    [Yy]* ) ;;
    * ) info "Aborted."; exit 0 ;;
esac

# ------------------------------------------------------------------
# 1. Stop and remove the systemd service
# ------------------------------------------------------------------
if [[ -f "$SERVICE_FILE" ]]; then
    info "Stopping and disabling systemd service..."
    sudo systemctl stop rpi-uvc-gadget.service 2>/dev/null || true
    sudo systemctl disable rpi-uvc-gadget.service 2>/dev/null || true
    sudo rm -f "$SERVICE_FILE"
    sudo systemctl daemon-reload
    ok "systemd service removed."
else
    warn "systemd service not found — skipping."
fi

# ------------------------------------------------------------------
# 2. Remove the gadget script
# ------------------------------------------------------------------
if [[ -f "$GADGET_SCRIPT" ]]; then
    info "Removing gadget script..."
    rm -f "$GADGET_SCRIPT"
    ok "Gadget script removed."
else
    warn "Gadget script not found — skipping."
fi

# ------------------------------------------------------------------
# 3. Remove any rc.local entry (in case of older installs)
# ------------------------------------------------------------------
RC_LOCAL="/etc/rc.local"
if [[ -f "$RC_LOCAL" ]] && grep -qF ".rpi-uvc-gadget.sh" "$RC_LOCAL" 2>/dev/null; then
    info "Cleaning rc.local entry..."
    sudo sed -i '\|\.rpi-uvc-gadget\.sh|d' "$RC_LOCAL"
    ok "rc.local cleaned."
fi

# ------------------------------------------------------------------
# 4. Uninstall uvc-gadget binaries
# ------------------------------------------------------------------
if [[ -d "${UVC_DIR}/build" ]]; then
    info "Uninstalling uvc-gadget binaries..."
    sudo ninja -C "${UVC_DIR}/build" uninstall 2>/dev/null || {
        # Manual cleanup if meson uninstall isn't available
        warn "ninja uninstall failed — removing known paths manually..."
        sudo rm -f /usr/local/bin/uvc-gadget
        sudo rm -f /usr/local/lib/aarch64-linux-gnu/libuvcgadget.so*
        sudo rm -rf /usr/local/include/uvcgadget
        sudo rm -f /usr/local/lib/aarch64-linux-gnu/pkgconfig/uvcgadget.pc
    }
    sudo ldconfig
    ok "uvc-gadget binaries removed."
else
    warn "uvc-gadget build directory not found — skipping binary removal."
fi

# ------------------------------------------------------------------
# 5. Remove the uvc-gadget source directory
# ------------------------------------------------------------------
if [[ -d "$UVC_DIR" ]]; then
    info "Removing uvc-gadget source directory..."
    rm -rf "$UVC_DIR"
    ok "Source directory removed."
else
    warn "Source directory not found — skipping."
fi

# ------------------------------------------------------------------
# 6. Remove dwc2 overlay from boot config
# ------------------------------------------------------------------
if grep -qF "$DWC2_LINE" "$BOOT_CONFIG" 2>/dev/null; then
    info "Removing dwc2 OTG overlay from ${BOOT_CONFIG}..."
    sudo sed -i "\|${DWC2_LINE}|d" "$BOOT_CONFIG"
    ok "dwc2 overlay removed."
else
    warn "dwc2 overlay not found in ${BOOT_CONFIG} — skipping."
fi

# ------------------------------------------------------------------
# Done
# ------------------------------------------------------------------
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Uninstall complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "Build dependencies (git, meson, libcamera-dev, libjpeg-dev)"
echo -e "were ${YELLOW}not${NC} removed — they may be used by other software."
echo -e "Remove them manually with: ${CYAN}sudo apt remove git meson libcamera-dev libjpeg-dev${NC}"
echo ""
read -rp "Reboot now? [y/N] " yn
case "$yn" in
    [Yy]* ) sudo reboot ;;
    * ) info "Remember to reboot to fully clear the dwc2 overlay." ;;
esac
