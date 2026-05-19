#!/bin/bash
# ============================================================================
# Raspberry Pi USB Webcam — Interactive Installer v3.0
# https://github.com/Delulu-Delilah/rpi-uvc-webcam
# ============================================================================
main() {
set -euo pipefail
REPO="https://raw.githubusercontent.com/Delulu-Delilah/rpi-uvc-webcam/main"
CONFIG_FILE="/etc/rpi-webcam.conf"
UPDATE_MODE=0
[[ "${1:-}" == "--update" ]] && UPDATE_MODE=1

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'
info() { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()   { echo -e "${GREEN}[ OK ]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail() { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }

[[ $(id -u) -eq 0 ]] && fail "Do NOT run as root."
CURRENT_USER=$(whoami)

if ! command -v whiptail &>/dev/null; then
    info "Installing whiptail..."; sudo apt-get update -y && sudo apt-get install -y whiptail
fi
WT_H=18; WT_W=72; WT_MH=8

wt() { local r; r=$(whiptail "$@" 3>&1 1>&2 2>&3) || { echo ""; return 1; }; echo "$r"; }

# ══════════════════════════════════════════════════════════════
# TUI WIZARD (skipped in --update mode)
# ══════════════════════════════════════════════════════════════
if [[ "$UPDATE_MODE" == "1" ]]; then
    [[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"
    RECONFIGURE=0
else

whiptail --title "  📷  Pi Webcam Installer v3  " --msgbox "\
Welcome to the Raspberry Pi USB Webcam installer!

⚠  IMPORTANT: You must use Raspberry Pi OS Lite
   (the headless version — no desktop environment).
   In Raspberry Pi Imager, look for any option
   ending in \"Lite\" under Raspberry Pi OS.

This wizard sets up your Pi as a webcam with:
 • USB plug-and-play OR network MJPEG streaming
 • Camera rotation controls
 • A management CLI: pi-webcam
 • Optional auto-updates

Press OK to begin." 22 $WT_W

if [[ -f "$CONFIG_FILE" ]]; then
    if whiptail --title "  Existing Configuration  " --yesno \
        "An existing configuration was found.\n\nReconfigure? (No = keep current settings)" 10 $WT_W; then
        RECONFIGURE=1
    else
        RECONFIGURE=0; source "$CONFIG_FILE"
    fi
else
    RECONFIGURE=1
fi

if [[ "$RECONFIGURE" == "1" ]]; then

WEBCAM_PI_MODEL=$(wt --title "  Pi Model  " --radiolist "\nSelect your Raspberry Pi:\n" $WT_H $WT_W $WT_MH \
    "zero2w" "Pi Zero 2 W  [OTG]" ON "zerow" "Pi Zero W  [OTG]" OFF \
    "pi4b" "Pi 4 Model B  [OTG]" OFF "pi5" "Pi 5" OFF "other" "Other" OFF) || fail "Cancelled."

WEBCAM_CAMERA=$(wt --title "  Camera  " --radiolist "\nSelect your camera module:\n" $WT_H $WT_W $WT_MH \
    "cam3" "Camera Module 3" ON "cam3w" "Camera Module 3 Wide" OFF \
    "cam2" "Camera Module 2" OFF "cam2noir" "Camera Module 2 NoIR" OFF \
    "hq" "HQ Camera" OFF "gs" "Global Shutter" OFF "other" "Other" OFF) || fail "Cancelled."

WEBCAM_PRODUCT=$(wt --title "  Device Name  " --inputbox \
    "\nName shown in Zoom, Teams, etc.:\n" 12 $WT_W "Pi Webcam") || fail "Cancelled."
[[ -z "$WEBCAM_PRODUCT" ]] && WEBCAM_PRODUCT="Pi Webcam"

RES=$(wt --title "  Resolutions  " --checklist "\nSelect resolutions to advertise:\n" $WT_H $WT_W $WT_MH \
    "480p" "640×480  (VGA)" ON "720p" "1280×720  (HD)" ON "1080p" "1920×1080  (Full HD)" ON) || fail "Cancelled."
WEBCAM_RES_480P=0; WEBCAM_RES_720P=0; WEBCAM_RES_1080P=0
[[ "$RES" == *"480p"* ]] && WEBCAM_RES_480P=1
[[ "$RES" == *"720p"* ]] && WEBCAM_RES_720P=1
[[ "$RES" == *"1080p"* ]] && WEBCAM_RES_1080P=1
[[ "$WEBCAM_RES_480P$WEBCAM_RES_720P$WEBCAM_RES_1080P" == "000" ]] && fail "Select at least one resolution."

WEBCAM_MODE=$(wt --title "  Streaming Mode  " --radiolist \
    "\nUSB: Plug-and-play webcam via USB cable.\nNetwork: MJPEG stream over HTTP (browser-viewable).\n" \
    14 $WT_W 3 "usb" "USB Webcam (plug-and-play)" ON "network" "Network Stream (MJPEG/HTTP)" OFF) || fail "Cancelled."

ROT=$(wt --title "  Camera Rotation  " --radiolist \
    "\nCorrect the camera orientation if needed.\n(You can change this later with: pi-webcam rotate)\n" \
    16 $WT_W 5 "none" "No rotation (0°)" ON "180" "Rotate 180°" OFF \
    "hflip" "Horizontal flip" OFF "vflip" "Vertical flip" OFF) || fail "Cancelled."
WEBCAM_HFLIP=0; WEBCAM_VFLIP=0
case "$ROT" in 180) WEBCAM_HFLIP=1; WEBCAM_VFLIP=1;; hflip) WEBCAM_HFLIP=1;; vflip) WEBCAM_VFLIP=1;; esac

if whiptail --title "  Auto Updates  " --yesno \
    "Enable weekly auto-updates?\n\nThe Pi will check GitHub for new versions and\nautomatically install improvements.\n\n(Toggle later with: pi-webcam update --auto-on/off)" \
    14 $WT_W; then WEBCAM_AUTO_UPDATE=1; else WEBCAM_AUTO_UPDATE=0; fi

# Confirmation
case "$WEBCAM_PI_MODEL" in zero2w) PL="Pi Zero 2 W";; zerow) PL="Pi Zero W";; pi4b) PL="Pi 4B";; pi5) PL="Pi 5";; *) PL="Other";; esac
case "$WEBCAM_CAMERA" in cam3) CL="Cam Module 3";; cam3w) CL="Cam3 Wide";; cam2) CL="Cam Module 2";; cam2noir) CL="Cam2 NoIR";; hq) CL="HQ Camera";; gs) CL="Global Shutter";; *) CL="Other";; esac
RL=""; [[ "$WEBCAM_RES_480P" == "1" ]] && RL+="480p "; [[ "$WEBCAM_RES_720P" == "1" ]] && RL+="720p "; [[ "$WEBCAM_RES_1080P" == "1" ]] && RL+="1080p"
ROTL="None"; [[ "$WEBCAM_HFLIP$WEBCAM_VFLIP" == "11" ]] && ROTL="180°"; [[ "$WEBCAM_HFLIP$WEBCAM_VFLIP" == "10" ]] && ROTL="H-Flip"; [[ "$WEBCAM_HFLIP$WEBCAM_VFLIP" == "01" ]] && ROTL="V-Flip"

whiptail --title "  Confirm  " --yesno "\
  Pi Model ........... $PL
  Camera ............. $CL
  Device Name ........ $WEBCAM_PRODUCT
  Resolutions ........ $RL
  Mode ............... $WEBCAM_MODE
  Rotation ........... $ROTL
  Auto Updates ....... $([ "$WEBCAM_AUTO_UPDATE" == "1" ] && echo Yes || echo No)

Proceed with installation?" $WT_H $WT_W || fail "Cancelled."

fi  # RECONFIGURE
fi  # UPDATE_MODE

# ══════════════════════════════════════════════════════════════
# INSTALL
# ══════════════════════════════════════════════════════════════

# Defaults for variables that might not be set
WEBCAM_MODE="${WEBCAM_MODE:-usb}"
WEBCAM_HFLIP="${WEBCAM_HFLIP:-0}"; WEBCAM_VFLIP="${WEBCAM_VFLIP:-0}"
WEBCAM_AUTO_UPDATE="${WEBCAM_AUTO_UPDATE:-0}"
WEBCAM_NETWORK_PORT="${WEBCAM_NETWORK_PORT:-8080}"
WEBCAM_RES_480P="${WEBCAM_RES_480P:-1}"; WEBCAM_RES_720P="${WEBCAM_RES_720P:-1}"; WEBCAM_RES_1080P="${WEBCAM_RES_1080P:-1}"

# ── Save config ──────────────────────────────────────────────
info "Saving configuration..."
sudo tee "$CONFIG_FILE" >/dev/null <<CONFEOF
# Pi Webcam Configuration — v3.0
WEBCAM_PI_MODEL="${WEBCAM_PI_MODEL:-zero2w}"
WEBCAM_CAMERA="${WEBCAM_CAMERA:-other}"
WEBCAM_PRODUCT="${WEBCAM_PRODUCT:-Pi Webcam}"
WEBCAM_RES_480P="${WEBCAM_RES_480P}"
WEBCAM_RES_720P="${WEBCAM_RES_720P}"
WEBCAM_RES_1080P="${WEBCAM_RES_1080P}"
WEBCAM_VID="0x0525"
WEBCAM_PID="0xa4a2"
WEBCAM_MODE="${WEBCAM_MODE}"
WEBCAM_HFLIP="${WEBCAM_HFLIP}"
WEBCAM_VFLIP="${WEBCAM_VFLIP}"
WEBCAM_AUTO_UPDATE="${WEBCAM_AUTO_UPDATE}"
WEBCAM_NETWORK_PORT="${WEBCAM_NETWORK_PORT}"
WEBCAM_VERSION="3.0.0"
CONFEOF
ok "Configuration saved."

# ── System update ────────────────────────────────────────────
info "Updating packages..."
sudo apt-get update -y
sudo apt-get full-upgrade -y
ok "Packages updated."

# ── dwc2 overlay ─────────────────────────────────────────────
BOOT_CONFIG="/boot/firmware/config.txt"
[[ ! -f "$BOOT_CONFIG" ]] && BOOT_CONFIG="/boot/config.txt"
DWC2="dtoverlay=dwc2,dr_mode=otg"
if grep -qF "$DWC2" "$BOOT_CONFIG" 2>/dev/null; then ok "dwc2 overlay present."
else echo "$DWC2" | sudo tee -a "$BOOT_CONFIG" >/dev/null; ok "dwc2 overlay added."; fi

# ── Dependencies ─────────────────────────────────────────────
info "Installing dependencies..."
sudo apt-get install -y git meson libcamera-dev libjpeg-dev qrencode
if [[ "$WEBCAM_MODE" == "network" ]]; then
    sudo apt-get install -y python3-picamera2 python3-pil
fi
ok "Dependencies installed."

# ── Build uvc-gadget ─────────────────────────────────────────
UVC_DIR="${HOME}/uvc-gadget"
if [[ -d "$UVC_DIR" ]]; then git -C "$UVC_DIR" pull --ff-only || true
else git clone https://gitlab.freedesktop.org/camera/uvc-gadget.git "$UVC_DIR"; fi
info "Building uvc-gadget..."
cd "$UVC_DIR"; [[ -d build ]] && rm -rf build
meson setup build; ninja -C build; sudo ninja -C build install; sudo ldconfig
ok "uvc-gadget built."

# ── Deploy gadget script ─────────────────────────────────────
GADGET_SCRIPT="${HOME}/.rpi-uvc-gadget.sh"
info "Writing gadget script..."
cat > "$GADGET_SCRIPT" << 'GADGETEOF'
#!/bin/bash
source /etc/rpi-webcam.conf 2>/dev/null
CONFIGFS="/sys/kernel/config"; GADGET="$CONFIGFS/usb_gadget"
VID="${WEBCAM_VID:-0x0525}"; PID="${WEBCAM_PID:-0xa4a2}"
SERIAL="0123456789"; MANUF=$(hostname)
PRODUCT="${WEBCAM_PRODUCT:-UVC Gadget}"
BOARD=$(strings /proc/device-tree/model); UDC=$(ls /sys/class/udc)
create_frame() {
	FUNCTION=$1; WIDTH=$2; HEIGHT=$3; FORMAT=$4; NAME=$5
	wdir=functions/$FUNCTION/streaming/$FORMAT/$NAME/${HEIGHT}p
	mkdir -p $wdir; echo $WIDTH > $wdir/wWidth; echo $HEIGHT > $wdir/wHeight
	echo $(( $WIDTH * $HEIGHT * 2 )) > $wdir/dwMaxVideoFrameBufferSize
	cat <<EOF > $wdir/dwFrameInterval
$6
EOF
}
create_uvc() {
	CONFIG=$1; FUNCTION=$2; mkdir functions/$FUNCTION
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
	ln -sf ../../uncompressed/u 2>/dev/null; ln -sf ../../mjpeg/m 2>/dev/null
	cd ../../class/fs; ln -sf ../../header/h; cd ../../class/hs; ln -sf ../../header/h
	cd ../../class/ss; ln -sf ../../header/h; cd ../../../control; mkdir -p header/h
	ln -sf header/h class/fs; ln -sf header/h class/ss; cd ../../../
	echo 2048 > functions/$FUNCTION/streaming_maxpacket
	ln -sf functions/$FUNCTION configs/c.1
}
modprobe libcomposite
if [ ! -d $GADGET/g1 ]; then
	mkdir -p $GADGET/g1; cd $GADGET/g1 || exit 1
	echo $VID > idVendor; echo $PID > idProduct
	mkdir -p strings/0x409
	echo $SERIAL > strings/0x409/serialnumber; echo $MANUF > strings/0x409/manufacturer
	echo $PRODUCT > strings/0x409/product; mkdir -p configs/c.1/strings/0x409
	create_uvc configs/c.1 uvc.0
	echo $UDC > UDC
fi
uvc-gadget -c 0 uvc.0
GADGETEOF
sudo chmod +x "$GADGET_SCRIPT"
ok "Gadget script written."

# ── Deploy scripts from repo ─────────────────────────────────
info "Installing pi-webcam CLI..."
sudo curl -sSL "${REPO}/scripts/pi-webcam" -o /usr/local/bin/pi-webcam
sudo chmod +x /usr/local/bin/pi-webcam
ok "CLI installed."

info "Installing scripts..."
sudo mkdir -p /usr/local/lib/rpi-webcam
sudo curl -sSL "${REPO}/scripts/mjpeg-server.py" -o /usr/local/lib/rpi-webcam/mjpeg-server.py
sudo curl -sSL "${REPO}/scripts/auto-update.sh" -o /usr/local/lib/rpi-webcam/auto-update.sh
sudo curl -sSL "${REPO}/scripts/timelapse.sh" -o /usr/local/lib/rpi-webcam/timelapse.sh
sudo chmod +x /usr/local/lib/rpi-webcam/auto-update.sh /usr/local/lib/rpi-webcam/timelapse.sh
ok "Scripts installed."

# ── MOTD banner ──────────────────────────────────────────────
info "Installing SSH banner..."
sudo tee /etc/profile.d/rpi-webcam-status.sh >/dev/null <<'MOTDEOF'
#!/bin/bash
[[ $- != *i* ]] && return; [[ -z "$PS1" ]] && return
_N='\033[0m'; _G='\033[0;32m'; _R='\033[0;31m'; _C='\033[0;36m'
_W='\033[1;37m'; _D='\033[2m'; _B='\033[0;90m'; _Y='\033[1;33m'
WEBCAM_PRODUCT="UVC Gadget"; WEBCAM_MODE="usb"; WEBCAM_HFLIP="0"; WEBCAM_VFLIP="0"
WEBCAM_RES_480P=0; WEBCAM_RES_720P=0; WEBCAM_RES_1080P=0; WEBCAM_AUTO_UPDATE=0
WEBCAM_CAMERA="other"; WEBCAM_NETWORK_PORT="8080"
[[ -f /etc/rpi-webcam.conf ]] && source /etc/rpi-webcam.conf
if systemctl is-active --quiet rpi-uvc-gadget.service 2>/dev/null; then _S="${_G}● Active${_N}";
elif systemctl is-active --quiet rpi-webcam-network.service 2>/dev/null; then _S="${_G}● Active${_N}";
else _S="${_R}● Inactive${_N}"; fi
_HELLO=$(command -v rpicam-hello||command -v libcamera-hello||echo "")
_CD="${_R}✗ Not found${_N}"
if [[ -n "$_HELLO" ]]; then _cdet=$($_HELLO --list-cameras 2>&1||true)
[[ "$_cdet" == *"Available"* || "$_cdet" == *"imx"* || "$_cdet" == *"ov"* ]] && _CD="${_G}✓ Detected${_N}"; fi
_RS=""; [[ "$WEBCAM_RES_480P" == "1" ]] && _RS+="480p "; [[ "$WEBCAM_RES_720P" == "1" ]] && _RS+="720p "
[[ "$WEBCAM_RES_1080P" == "1" ]] && _RS+="1080p"; _RS="${_RS:- none}"
_ROT="None"; [[ "$WEBCAM_HFLIP$WEBCAM_VFLIP" == "11" ]] && _ROT="180°"
[[ "$WEBCAM_HFLIP$WEBCAM_VFLIP" == "10" ]] && _ROT="H-Flip"; [[ "$WEBCAM_HFLIP$WEBCAM_VFLIP" == "01" ]] && _ROT="V-Flip"
if [[ "$WEBCAM_MODE" == "network" ]]; then _ip=$(hostname -I 2>/dev/null|awk '{print $1}')
_MD="Network · http://${_ip}:${WEBCAM_NETWORK_PORT}"; else _MD="USB Webcam"; fi
_UP="Manual"; [[ "$WEBCAM_AUTO_UPDATE" == "1" ]] && _UP="Auto (weekly)"
_bar="${_B}$(printf '─%.0s' {1..48})${_N}"
echo ""; echo -e "  ${_B}┌${_bar}┐${_N}"
echo -e "  ${_B}│${_N}  ${_W}📷  Pi Webcam${_N}                                  ${_B}│${_N}"
echo -e "  ${_B}├${_bar}┤${_N}"
printf "  ${_B}│${_N}  ${_W}Service${_N}   ${_D}·····${_N}  %-31b${_B}│${_N}\n" "$_S"
printf "  ${_B}│${_N}  ${_W}Mode${_N}      ${_D}·····${_N}  %-31s${_B}│${_N}\n" "$_MD"
printf "  ${_B}│${_N}  ${_W}Camera${_N}    ${_D}·····${_N}  %-31b${_B}│${_N}\n" "$_CD"
printf "  ${_B}│${_N}  ${_W}Device${_N}    ${_D}·····${_N}  %-31s${_B}│${_N}\n" "\"${WEBCAM_PRODUCT}\""
printf "  ${_B}│${_N}  ${_W}Formats${_N}   ${_D}·····${_N}  %-31s${_B}│${_N}\n" "$_RS"
printf "  ${_B}│${_N}  ${_W}Rotation${_N}  ${_D}·····${_N}  %-31s${_B}│${_N}\n" "$_ROT"
printf "  ${_B}│${_N}  ${_W}Updates${_N}   ${_D}·····${_N}  %-31s${_B}│${_N}\n" "$_UP"
echo -e "  ${_B}│${_N}                                                ${_B}│${_N}"
echo -e "  ${_B}│${_N}  ${_D}Run ${_C}pi-webcam${_D} for options${_N}                      ${_B}│${_N}"
echo -e "  ${_B}└${_bar}┘${_N}"; echo ""
MOTDEOF
sudo chmod +x /etc/profile.d/rpi-webcam-status.sh
ok "SSH banner installed."

# ── Systemd services ─────────────────────────────────────────
info "Creating systemd services..."

# USB gadget service
sudo tee /etc/systemd/system/rpi-uvc-gadget.service >/dev/null <<SVCEOF
[Unit]
Description=Pi Webcam — USB UVC Gadget
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

# Network streaming service
sudo tee /etc/systemd/system/rpi-webcam-network.service >/dev/null <<'NETSVCEOF'
[Unit]
Description=Pi Webcam — MJPEG Network Stream
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/lib/rpi-webcam/mjpeg-server.py
Restart=on-failure
RestartSec=3
[Install]
WantedBy=multi-user.target
NETSVCEOF

# Auto-update timer + service
sudo tee /etc/systemd/system/rpi-webcam-update.service >/dev/null <<'UPDSVCEOF'
[Unit]
Description=Pi Webcam — Auto Update
[Service]
Type=oneshot
ExecStart=/usr/local/lib/rpi-webcam/auto-update.sh
UPDSVCEOF

sudo tee /etc/systemd/system/rpi-webcam-update.timer >/dev/null <<'UPDTEOF'
[Unit]
Description=Pi Webcam — Weekly Update Check
[Timer]
OnCalendar=weekly
Persistent=true
RandomizedDelaySec=3600
[Install]
WantedBy=timers.target
UPDTEOF

# Timelapse service
sudo tee /etc/systemd/system/rpi-webcam-timelapse.service >/dev/null <<'TLEOF'
[Unit]
Description=Pi Webcam — Timelapse Capture
[Service]
Type=simple
ExecStart=/usr/local/lib/rpi-webcam/timelapse.sh
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
TLEOF

sudo systemctl daemon-reload

# Enable the selected mode
if [[ "$WEBCAM_MODE" == "network" ]]; then
    sudo systemctl disable rpi-uvc-gadget.service 2>/dev/null || true
    sudo systemctl enable rpi-webcam-network.service
else
    sudo systemctl disable rpi-webcam-network.service 2>/dev/null || true
    sudo systemctl enable rpi-uvc-gadget.service
fi

# Auto-update timer
if [[ "$WEBCAM_AUTO_UPDATE" == "1" ]]; then
    sudo systemctl enable rpi-webcam-update.timer
else
    sudo systemctl disable rpi-webcam-update.timer 2>/dev/null || true
fi
ok "Services configured."

# ── Completion ────────────────────────────────────────────────
if [[ "$UPDATE_MODE" == "1" ]]; then
    ok "Update complete (v3.1.0)."
else
    whiptail --title "  ✅  Installation Complete!  " --msgbox "\
Your Pi is configured as a webcam!

Management CLI — run pi-webcam for all options:
  pi-webcam status / mode / rotate / test
  pi-webcam image / night / overlay
  pi-webcam timelapse / auth / wifi
  pi-webcam diag / backup / update / logs

$([ "$WEBCAM_MODE" == "network" ] && echo "Stream: http://$(hostname -I 2>/dev/null|awk '{print $1}'):${WEBCAM_NETWORK_PORT}" || echo "Plug into USB data port after reboot.")" $WT_H $WT_W

    echo ""
    echo -e "${GREEN}  Installation complete!${NC}"
    echo ""
    read -rp "Reboot now? [y/N] " yn
    [[ "$yn" =~ ^[Yy] ]] && sudo reboot || info "Reboot when ready."
fi
}
main "$@"
