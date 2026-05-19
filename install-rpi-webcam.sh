#!/bin/bash
# ============================================================================
# Raspberry Pi USB Webcam (UVC Gadget) — Interactive Installer v2.0
# https://github.com/Delulu-Delilah/rpi-uvc-webcam
# ============================================================================

main() {
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }

# ── Pre-flight ────────────────────────────────────────────────────────
[[ $(id -u) -eq 0 ]] && fail "Do NOT run as root. Run as your normal user."

CURRENT_USER=$(whoami)
CONFIG_FILE="/etc/rpi-webcam.conf"

# Ensure whiptail is available
if ! command -v whiptail &>/dev/null; then
    info "Installing whiptail..."
    sudo apt-get update -y && sudo apt-get install -y whiptail
fi

# ── Whiptail sizing ──────────────────────────────────────────────────
WT_H=18; WT_W=72; WT_MH=8

# Helper: run whiptail, abort on cancel
wt() {
    local result
    result=$(whiptail "$@" 3>&1 1>&2 2>&3) || { echo ""; return 1; }
    echo "$result"
}

# ══════════════════════════════════════════════════════════════════════
#  TUI WIZARD
# ══════════════════════════════════════════════════════════════════════

# ── Welcome ───────────────────────────────────────────────────────────
whiptail --title "  📷  Pi Webcam Installer  " --msgbox "\
Welcome to the Raspberry Pi USB Webcam installer!

This wizard will walk you through setting up your
Raspberry Pi as a plug-and-play USB webcam.

What happens:
 • Installs required packages & builds uvc-gadget
 • Configures USB OTG (dwc2 overlay)
 • Creates a systemd service for auto-start
 • Adds an SSH login status banner

Press OK to begin." $WT_H $WT_W

# ── Existing config check ────────────────────────────────────────────
if [[ -f "$CONFIG_FILE" ]]; then
    if whiptail --title "  Existing Configuration  " --yesno \
        "An existing webcam configuration was found.\n\nWould you like to reconfigure? (No = keep current settings)" \
        10 $WT_W; then
        RECONFIGURE=1
    else
        RECONFIGURE=0
        source "$CONFIG_FILE"
    fi
else
    RECONFIGURE=1
fi

if [[ "$RECONFIGURE" == "1" ]]; then

# ── Pi Model ──────────────────────────────────────────────────────────
WEBCAM_PI_MODEL=$(wt --title "  Select Your Pi Model  " --radiolist \
"\nChoose the Raspberry Pi you are using.\nModels marked [OTG] support single-cable operation.\n" \
$WT_H $WT_W $WT_MH \
    "zero2w"  "Raspberry Pi Zero 2 W  [OTG]" ON \
    "zerow"   "Raspberry Pi Zero W    [OTG]" OFF \
    "pi4b"    "Raspberry Pi 4 Model B [OTG]" OFF \
    "pi5"     "Raspberry Pi 5"               OFF \
    "other"   "Other / Not listed"           OFF \
) || fail "Setup cancelled."

# ── Camera ────────────────────────────────────────────────────────────
WEBCAM_CAMERA=$(wt --title "  Select Your Camera  " --radiolist \
"\nChoose your camera module.\n" \
$WT_H $WT_W $WT_MH \
    "cam3"     "Camera Module 3"              ON \
    "cam3w"    "Camera Module 3 (Wide)"       OFF \
    "cam2"     "Camera Module 2"              OFF \
    "cam2noir" "Camera Module 2 NoIR"         OFF \
    "hq"       "HQ Camera / HQ M12"          OFF \
    "gs"       "Global Shutter Camera"        OFF \
    "other"    "Other / Third-party"          OFF \
) || fail "Setup cancelled."

# ── Device Name ───────────────────────────────────────────────────────
WEBCAM_PRODUCT=$(wt --title "  Device Name  " --inputbox \
"\nThis name appears in Zoom, Teams, etc.\nwhen selecting your camera.\n" \
12 $WT_W "Pi Webcam") || fail "Setup cancelled."
[[ -z "$WEBCAM_PRODUCT" ]] && WEBCAM_PRODUCT="Pi Webcam"

# ── Resolutions ───────────────────────────────────────────────────────
RES_CHOICES=$(wt --title "  Video Resolutions  " --checklist \
"\nSelect which resolutions to advertise.\nAll selected resolutions support both MJPEG and uncompressed.\n" \
$WT_H $WT_W $WT_MH \
    "480p"   "640×480   (VGA)      — best compatibility" ON \
    "720p"   "1280×720  (HD)       — good balance"       ON \
    "1080p"  "1920×1080 (Full HD)  — highest quality"    ON \
) || fail "Setup cancelled."

# Parse checklist output
WEBCAM_RES_480P=0; WEBCAM_RES_720P=0; WEBCAM_RES_1080P=0
[[ "$RES_CHOICES" == *"480p"* ]]  && WEBCAM_RES_480P=1
[[ "$RES_CHOICES" == *"720p"* ]]  && WEBCAM_RES_720P=1
[[ "$RES_CHOICES" == *"1080p"* ]] && WEBCAM_RES_1080P=1

if [[ "$WEBCAM_RES_480P" == "0" && "$WEBCAM_RES_720P" == "0" && "$WEBCAM_RES_1080P" == "0" ]]; then
    whiptail --title "  ⚠ Warning  " --msgbox "You must select at least one resolution." 8 $WT_W
    fail "No resolutions selected."
fi

# ── Build friendly names for confirmation ─────────────────────────────
case "$WEBCAM_PI_MODEL" in
    zero2w) PI_LABEL="Raspberry Pi Zero 2 W" ;;
    zerow)  PI_LABEL="Raspberry Pi Zero W" ;;
    pi4b)   PI_LABEL="Raspberry Pi 4 Model B" ;;
    pi5)    PI_LABEL="Raspberry Pi 5" ;;
    *)      PI_LABEL="Other" ;;
esac

case "$WEBCAM_CAMERA" in
    cam3)     CAM_LABEL="Camera Module 3" ;;
    cam3w)    CAM_LABEL="Camera Module 3 (Wide)" ;;
    cam2)     CAM_LABEL="Camera Module 2" ;;
    cam2noir) CAM_LABEL="Camera Module 2 NoIR" ;;
    hq)       CAM_LABEL="HQ Camera" ;;
    gs)       CAM_LABEL="Global Shutter Camera" ;;
    *)        CAM_LABEL="Other" ;;
esac

RES_LIST=""
[[ "$WEBCAM_RES_480P"  == "1" ]] && RES_LIST+="480p  "
[[ "$WEBCAM_RES_720P"  == "1" ]] && RES_LIST+="720p  "
[[ "$WEBCAM_RES_1080P" == "1" ]] && RES_LIST+="1080p "

# ── Confirmation ──────────────────────────────────────────────────────
whiptail --title "  Confirm Configuration  " --yesno "\
Review your settings:

  Pi Model ............. $PI_LABEL
  Camera ............... $CAM_LABEL
  Device Name .......... $WEBCAM_PRODUCT
  Resolutions .......... $RES_LIST

Proceed with installation?" $WT_H $WT_W || fail "Setup cancelled."

fi  # end RECONFIGURE block

# ══════════════════════════════════════════════════════════════════════
#  INSTALLATION
# ══════════════════════════════════════════════════════════════════════

# ── 1. Save configuration ────────────────────────────────────────────
info "Saving configuration to ${CONFIG_FILE}..."
sudo tee "$CONFIG_FILE" > /dev/null << CONFEOF
# Pi Webcam Configuration — generated by installer
WEBCAM_PI_MODEL="${WEBCAM_PI_MODEL}"
WEBCAM_CAMERA="${WEBCAM_CAMERA}"
WEBCAM_PRODUCT="${WEBCAM_PRODUCT}"
WEBCAM_RES_480P="${WEBCAM_RES_480P}"
WEBCAM_RES_720P="${WEBCAM_RES_720P}"
WEBCAM_RES_1080P="${WEBCAM_RES_1080P}"
WEBCAM_VID="0x0525"
WEBCAM_PID="0xa4a2"
CONFEOF
ok "Configuration saved."

# ── 2. System update ─────────────────────────────────────────────────
info "Updating package lists..."
sudo apt-get update -y
info "Upgrading installed packages..."
sudo apt-get full-upgrade -y
ok "System packages up to date."

# ── 3. Enable dwc2 OTG overlay ───────────────────────────────────────
BOOT_CONFIG="/boot/firmware/config.txt"
[[ ! -f "$BOOT_CONFIG" ]] && BOOT_CONFIG="/boot/config.txt"
DWC2_LINE="dtoverlay=dwc2,dr_mode=otg"

if grep -qF "$DWC2_LINE" "$BOOT_CONFIG" 2>/dev/null; then
    ok "dwc2 OTG overlay already present."
else
    info "Adding dwc2 OTG overlay to ${BOOT_CONFIG}..."
    echo "$DWC2_LINE" | sudo tee -a "$BOOT_CONFIG" > /dev/null
    ok "dwc2 OTG overlay added."
fi

# ── 4. Install dependencies ──────────────────────────────────────────
info "Installing build dependencies..."
sudo apt-get install -y git meson libcamera-dev libjpeg-dev
ok "Dependencies installed."

# ── 5. Clone & build uvc-gadget ──────────────────────────────────────
UVC_DIR="${HOME}/uvc-gadget"

if [[ -d "$UVC_DIR" ]]; then
    warn "uvc-gadget directory exists; pulling latest..."
    git -C "$UVC_DIR" pull --ff-only || true
else
    info "Cloning uvc-gadget..."
    git clone https://gitlab.freedesktop.org/camera/uvc-gadget.git "$UVC_DIR"
fi

info "Building uvc-gadget..."
cd "$UVC_DIR"
[[ -d build ]] && rm -rf build
meson setup build
ninja -C build
sudo ninja -C build install
sudo ldconfig
ok "uvc-gadget installed."

# ── 6. Write the gadget runtime script ────────────────────────────────
GADGET_SCRIPT="${HOME}/.rpi-uvc-gadget.sh"
info "Writing gadget script to ${GADGET_SCRIPT}..."

cat > "$GADGET_SCRIPT" << 'GADGETEOF'
#!/bin/bash
# ── Pi Webcam · UVC Gadget Runtime Script ──
# Sources /etc/rpi-webcam.conf for user configuration.

source /etc/rpi-webcam.conf 2>/dev/null

CONFIGFS="/sys/kernel/config"
GADGET="$CONFIGFS/usb_gadget"
VID="${WEBCAM_VID:-0x0525}"
PID="${WEBCAM_PID:-0xa4a2}"
SERIAL="0123456789"
MANUF=$(hostname)
PRODUCT="${WEBCAM_PRODUCT:-UVC Gadget}"
BOARD=$(strings /proc/device-tree/model)
UDC=$(ls /sys/class/udc)

create_frame() {
	FUNCTION=$1; WIDTH=$2; HEIGHT=$3; FORMAT=$4; NAME=$5
	wdir=functions/$FUNCTION/streaming/$FORMAT/$NAME/${HEIGHT}p
	mkdir -p $wdir
	echo $WIDTH  > $wdir/wWidth
	echo $HEIGHT > $wdir/wHeight
	echo $(( $WIDTH * $HEIGHT * 2 )) > $wdir/dwMaxVideoFrameBufferSize
	cat <<EOF > $wdir/dwFrameInterval
$6
EOF
}

create_uvc() {
	CONFIG=$1; FUNCTION=$2
	echo "  Creating UVC gadget: $FUNCTION"
	mkdir functions/$FUNCTION

	# ── 480p ──
	if [[ "${WEBCAM_RES_480P:-1}" == "1" ]]; then
		create_frame $FUNCTION 640 480 uncompressed u "333333
416667
500000
666666
1000000
1333333
2000000
"
		create_frame $FUNCTION 640 480 mjpeg m "333333
416667
500000
666666
1000000
1333333
2000000
"
	fi

	# ── 720p ──
	if [[ "${WEBCAM_RES_720P:-1}" == "1" ]]; then
		create_frame $FUNCTION 1280 720 uncompressed u "1000000
1333333
2000000
"
		create_frame $FUNCTION 1280 720 mjpeg m "333333
416667
500000
666666
1000000
1333333
2000000
"
	fi

	# ── 1080p ──
	if [[ "${WEBCAM_RES_1080P:-1}" == "1" ]]; then
		create_frame $FUNCTION 1920 1080 uncompressed u "2000000"
		create_frame $FUNCTION 1920 1080 mjpeg m "333333
416667
500000
666666
1000000
1333333
2000000
"
	fi

	mkdir functions/$FUNCTION/streaming/header/h
	cd functions/$FUNCTION/streaming/header/h

	[[ "${WEBCAM_RES_480P:-1}" == "1" || "${WEBCAM_RES_720P:-1}" == "1" || "${WEBCAM_RES_1080P:-1}" == "1" ]] && \
		ln -sf ../../uncompressed/u 2>/dev/null; ln -sf ../../mjpeg/m 2>/dev/null

	cd ../../class/fs;  ln -sf ../../header/h
	cd ../../class/hs;  ln -sf ../../header/h
	cd ../../class/ss;  ln -sf ../../header/h
	cd ../../../control; mkdir -p header/h
	ln -sf header/h class/fs
	ln -sf header/h class/ss
	cd ../../../

	echo 2048 > functions/$FUNCTION/streaming_maxpacket
	ln -sf functions/$FUNCTION configs/c.1
}

echo "Loading composite module"
modprobe libcomposite

if [ ! -d $GADGET/g1 ]; then
	echo "Detecting platform:"
	echo "  board : $BOARD"
	echo "  udc   : $UDC"

	mkdir -p $GADGET/g1
	cd $GADGET/g1 || { echo "Error creating gadget"; exit 1; }

	echo $VID > idVendor
	echo $PID > idProduct

	mkdir -p strings/0x409
	echo $SERIAL  > strings/0x409/serialnumber
	echo $MANUF   > strings/0x409/manufacturer
	echo $PRODUCT > strings/0x409/product

	mkdir -p configs/c.1/strings/0x409

	create_uvc configs/c.1 uvc.0

	echo "Binding USB Device Controller"
	echo $UDC > UDC
	echo "OK"
fi

uvc-gadget -c 0 uvc.0
GADGETEOF

sudo chmod +x "$GADGET_SCRIPT"
ok "Gadget script written."

# ── 7. Write SSH login banner (MOTD) ─────────────────────────────────
MOTD_SCRIPT="/etc/profile.d/rpi-webcam-status.sh"
info "Installing SSH status banner..."

sudo tee "$MOTD_SCRIPT" > /dev/null << 'MOTDEOF'
#!/bin/bash
# ── Pi Webcam · SSH Login Status Banner ──

# Only show on interactive login
[[ $- != *i* ]] && return
[[ -z "$PS1" ]] && return

_C_RST='\033[0m'
_C_BLD='\033[1m'
_C_DIM='\033[2m'
_C_CYN='\033[0;36m'
_C_GRN='\033[0;32m'
_C_RED='\033[0;31m'
_C_YLW='\033[1;33m'
_C_WHT='\033[1;37m'
_C_BOX='\033[0;90m'  # dark gray for box lines

# Load config
WEBCAM_PRODUCT="UVC Gadget"
WEBCAM_CAMERA="unknown"
WEBCAM_RES_480P=0; WEBCAM_RES_720P=0; WEBCAM_RES_1080P=0
[[ -f /etc/rpi-webcam.conf ]] && source /etc/rpi-webcam.conf

# Service status
if systemctl is-active --quiet rpi-uvc-gadget.service 2>/dev/null; then
    _STATUS="${_C_GRN}● Active${_C_RST}"
else
    _STATUS="${_C_RED}● Inactive${_C_RST}"
fi

# Camera label
case "${WEBCAM_CAMERA:-other}" in
    cam3)     _CAM="Camera Module 3" ;;
    cam3w)    _CAM="Camera Module 3 Wide" ;;
    cam2)     _CAM="Camera Module 2" ;;
    cam2noir) _CAM="Camera Module 2 NoIR" ;;
    hq)       _CAM="HQ Camera" ;;
    gs)       _CAM="Global Shutter" ;;
    *)        _CAM="Camera" ;;
esac

# Resolution list
_RES=""
[[ "${WEBCAM_RES_480P}"  == "1" ]] && _RES+="480p "
[[ "${WEBCAM_RES_720P}"  == "1" ]] && _RES+="720p "
[[ "${WEBCAM_RES_1080P}" == "1" ]] && _RES+="1080p "
_RES="${_RES:- none}"

# UDC status
if [[ -d /sys/class/udc ]] && ls /sys/class/udc/ &>/dev/null && [[ -n "$(ls /sys/class/udc/ 2>/dev/null)" ]]; then
    _UDC="${_C_GRN}Connected${_C_RST}"
else
    _UDC="${_C_YLW}No UDC${_C_RST}"
fi

# Box width
W=50
_BAR="${_C_BOX}$(printf '─%.0s' $(seq 1 $((W-2))))${_C_RST}"

echo ""
echo -e "  ${_C_BOX}┌${_BAR}┐${_C_RST}"
echo -e "  ${_C_BOX}│${_C_RST}${_C_BLD}${_C_CYN}        📷  Pi Webcam                          ${_C_RST}${_C_BOX}│${_C_RST}"
echo -e "  ${_C_BOX}├${_BAR}┤${_C_RST}"
echo -e "  ${_C_BOX}│${_C_RST}                                                ${_C_BOX}│${_C_RST}"
printf  "  ${_C_BOX}│${_C_RST}  ${_C_WHT}Service${_C_RST}  ${_C_DIM}·········${_C_RST}  %-29b${_C_BOX}│${_C_RST}\n" "$_STATUS"
printf  "  ${_C_BOX}│${_C_RST}  ${_C_WHT}Camera${_C_RST}   ${_C_DIM}·········${_C_RST}  %-29s${_C_BOX}│${_C_RST}\n" "$_CAM"
printf  "  ${_C_BOX}│${_C_RST}  ${_C_WHT}Device${_C_RST}   ${_C_DIM}·········${_C_RST}  %-29s${_C_BOX}│${_C_RST}\n" "\"${WEBCAM_PRODUCT}\""
printf  "  ${_C_BOX}│${_C_RST}  ${_C_WHT}Formats${_C_RST}  ${_C_DIM}·········${_C_RST}  %-29s${_C_BOX}│${_C_RST}\n" "$_RES"
printf  "  ${_C_BOX}│${_C_RST}  ${_C_WHT}USB${_C_RST}      ${_C_DIM}·········${_C_RST}  %-29b${_C_BOX}│${_C_RST}\n" "$_UDC"
echo -e "  ${_C_BOX}│${_C_RST}                                                ${_C_BOX}│${_C_RST}"
echo -e "  ${_C_BOX}└${_BAR}┘${_C_RST}"
echo ""
MOTDEOF

sudo chmod +x "$MOTD_SCRIPT"
ok "SSH status banner installed."

# ── 8. Create systemd service ─────────────────────────────────────────
SERVICE_FILE="/etc/systemd/system/rpi-uvc-gadget.service"
info "Creating systemd service..."

sudo tee "$SERVICE_FILE" > /dev/null << SVCEOF
[Unit]
Description=Raspberry Pi UVC USB Webcam Gadget
After=systemd-modules-load.service
ConditionPathIsDirectory=/sys/class/udc

[Service]
Type=simple
ExecStart=${GADGET_SCRIPT}
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
SVCEOF

sudo systemctl daemon-reload
sudo systemctl enable rpi-uvc-gadget.service
ok "systemd service created and enabled."

# ── 9. Completion ─────────────────────────────────────────────────────
whiptail --title "  ✅  Installation Complete!  " --msgbox "\
Your Raspberry Pi is now configured as a USB webcam!

Next steps:
  1. Shut down:  sudo shutdown -h now
  2. Connect your camera via the ribbon cable
  3. Put everything in a case
  4. Plug into your computer's USB data port
  5. Select \"${WEBCAM_PRODUCT}\" in Zoom / Teams / etc.

The status banner will appear each time you SSH in.
To reconfigure, run this installer again." $WT_H $WT_W

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Installation complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
read -rp "Reboot now? [y/N] " yn
case "$yn" in
    [Yy]* ) sudo reboot ;;
    * ) info "Remember to reboot before using the webcam." ;;
esac

}  # end main

main "$@"
