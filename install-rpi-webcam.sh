#!/bin/bash
# ============================================================================
# Raspberry Pi USB Webcam (UVC Gadget) — One-Shot Installer
# Based on: https://www.raspberrypi.com/tutorials/plug-and-play-raspberry-pi-usb-webcam/
#
# Run on a fresh Raspberry Pi OS (Legacy) Lite install over SSH:
#   curl -sSL https://raw.githubusercontent.com/<YOU>/rpi-uvc-webcam/main/install.sh | bash
#
# What this script does:
#   1. Updates all system packages
#   2. Enables the dwc2 OTG overlay in /boot/firmware/config.txt
#   3. Installs build dependencies (git, meson, libcamera-dev, libjpeg-dev)
#   4. Clones, builds, and installs uvc-gadget
#   5. Writes the UVC gadget setup script to ~/.rpi-uvc-gadget.sh
#   6. Registers the setup script in /etc/rc.local so it runs on every boot
#   7. Prompts to reboot
# ============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }

# ------------------------------------------------------------------
# Pre-flight checks
# ------------------------------------------------------------------
[[ $(id -u) -eq 0 ]] && fail "Do NOT run this script as root. Run as your normal user (sudo is used internally)."

CURRENT_USER=$(whoami)
info "Running as user: ${CURRENT_USER}"
info "Home directory:  ${HOME}"

# ------------------------------------------------------------------
# 1. System update
# ------------------------------------------------------------------
info "Updating package lists..."
sudo apt-get update -y
info "Upgrading installed packages..."
sudo apt-get full-upgrade -y
ok "System packages are up to date."

# ------------------------------------------------------------------
# 2. Enable dwc2 OTG overlay
# ------------------------------------------------------------------
BOOT_CONFIG="/boot/firmware/config.txt"
# Fallback for older OS images that use /boot/config.txt
[[ ! -f "$BOOT_CONFIG" ]] && BOOT_CONFIG="/boot/config.txt"

DWC2_LINE="dtoverlay=dwc2,dr_mode=otg"

if grep -qF "$DWC2_LINE" "$BOOT_CONFIG" 2>/dev/null; then
    ok "dwc2 OTG overlay already present in ${BOOT_CONFIG}."
else
    info "Appending dwc2 OTG overlay to ${BOOT_CONFIG}..."
    echo "$DWC2_LINE" | sudo tee -a "$BOOT_CONFIG" > /dev/null
    ok "dwc2 OTG overlay added."
fi

# ------------------------------------------------------------------
# 3. Install build dependencies
# ------------------------------------------------------------------
info "Installing build dependencies..."
sudo apt-get install -y git meson libcamera-dev libjpeg-dev
ok "Dependencies installed."

# ------------------------------------------------------------------
# 4. Clone, build, and install uvc-gadget
# ------------------------------------------------------------------
UVC_DIR="${HOME}/uvc-gadget"

if [[ -d "$UVC_DIR" ]]; then
    warn "uvc-gadget directory already exists at ${UVC_DIR}; pulling latest..."
    git -C "$UVC_DIR" pull --ff-only || true
else
    info "Cloning uvc-gadget..."
    git clone https://gitlab.freedesktop.org/camera/uvc-gadget.git "$UVC_DIR"
fi

info "Building uvc-gadget..."
cd "$UVC_DIR"
# meson setup (idempotent — wipe if exists)
[[ -d build ]] && rm -rf build
meson setup build
ninja -C build
sudo ninja -C build install
sudo ldconfig
ok "uvc-gadget installed."

# ------------------------------------------------------------------
# 5. Write the UVC gadget setup script
# ------------------------------------------------------------------
GADGET_SCRIPT="${HOME}/.rpi-uvc-gadget.sh"

info "Writing UVC gadget script to ${GADGET_SCRIPT}..."

cat > "$GADGET_SCRIPT" << 'GADGET_EOF'
#!/bin/bash

# Variables we need to make things easier later on.
CONFIGFS="/sys/kernel/config"
GADGET="$CONFIGFS/usb_gadget"
VID="0x0525"
PID="0xa4a2"
SERIAL="0123456789"
MANUF=$(hostname)
PRODUCT="UVC Gadget"
BOARD=$(strings /proc/device-tree/model)
UDC=$(ls /sys/class/udc) # will identify the 'first' UDC

# create_frame <function name> <width> <height> <format> <name> <intervals>
create_frame() {
	FUNCTION=$1
	WIDTH=$2
	HEIGHT=$3
	FORMAT=$4
	NAME=$5

	wdir=functions/$FUNCTION/streaming/$FORMAT/$NAME/${HEIGHT}p

	mkdir -p $wdir
	echo $WIDTH > $wdir/wWidth
	echo $HEIGHT > $wdir/wHeight
	echo $(( $WIDTH * $HEIGHT * 2 )) > $wdir/dwMaxVideoFrameBufferSize
	cat <<EOF > $wdir/dwFrameInterval
$6
EOF
}

create_uvc() {
	CONFIG=$1
	FUNCTION=$2

	echo "	Creating UVC gadget functionality : $FUNCTION"
	mkdir functions/$FUNCTION

	create_frame $FUNCTION 640 480 uncompressed u "333333
416667
500000
666666
1000000
1333333
2000000
"
	create_frame $FUNCTION 1280 720 uncompressed u "1000000
1333333
2000000
"
	create_frame $FUNCTION 1920 1080 uncompressed u "2000000"
	create_frame $FUNCTION 640 480 mjpeg m "333333
416667
500000
666666
1000000
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
	create_frame $FUNCTION 1920 1080 mjpeg m "333333
416667
500000
666666
1000000
1333333
2000000
"

	mkdir functions/$FUNCTION/streaming/header/h
	cd functions/$FUNCTION/streaming/header/h
	ln -s ../../uncompressed/u
	ln -s ../../mjpeg/m
	cd ../../class/fs
	ln -s ../../header/h
	cd ../../class/hs
	ln -s ../../header/h
	cd ../../class/ss
	ln -s ../../header/h
	cd ../../../control
	mkdir header/h
	ln -s header/h class/fs
	ln -s header/h class/ss
	cd ../../../

	echo 2048 > functions/$FUNCTION/streaming_maxpacket

	ln -s functions/$FUNCTION configs/c.1
}

echo "Loading composite module"
modprobe libcomposite

if [ ! -d $GADGET/g1 ]; then
	echo "Detecting platform:"
	echo "  board : $BOARD"
	echo "  udc   : $UDC"

	echo "Creating the USB gadget"

	echo "Creating gadget directory g1"
	mkdir -p $GADGET/g1

	cd $GADGET/g1
	if [ $? -ne 0 ]; then
		echo "Error creating usb gadget in configfs"
		exit 1;
	else
		echo "OK"
	fi

	echo "Setting Vendor and Product ID's"
	echo $VID > idVendor
	echo $PID > idProduct
	echo "OK"

	echo "Setting English strings"
	mkdir -p strings/0x409
	echo $SERIAL > strings/0x409/serialnumber
	echo $MANUF > strings/0x409/manufacturer
	echo $PRODUCT > strings/0x409/product
	echo "OK"

	echo "Creating Config"
	mkdir configs/c.1
	mkdir configs/c.1/strings/0x409

	echo "Creating functions..."

	create_uvc configs/c.1 uvc.0

	echo "OK"

	echo "Binding USB Device Controller"
	echo $UDC > UDC
	echo "OK"
fi

uvc-gadget -c 0 uvc.0
GADGET_EOF

sudo chmod +x "$GADGET_SCRIPT"
ok "Gadget script written and marked executable."

# ------------------------------------------------------------------
# 6. Register in /etc/rc.local
# ------------------------------------------------------------------
RC_LOCAL="/etc/rc.local"
LAUNCH_LINE="${GADGET_SCRIPT} &"

if grep -qF "$GADGET_SCRIPT" "$RC_LOCAL" 2>/dev/null; then
    ok "rc.local already contains the gadget launch line."
else
    info "Adding gadget script to ${RC_LOCAL}..."
    # Insert our line just before 'exit 0'
    sudo sed -i "/^exit 0$/i ${LAUNCH_LINE}" "$RC_LOCAL"
    ok "rc.local updated."
fi

# ------------------------------------------------------------------
# 7. Done — prompt reboot
# ------------------------------------------------------------------
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Installation complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "Next steps:"
echo -e "  1. ${CYAN}sudo shutdown -h now${NC}"
echo -e "  2. Connect your camera module via the ribbon cable."
echo -e "  3. Put everything in a case."
echo -e "  4. Plug the Pi into your computer's USB port."
echo -e "  5. Select ${YELLOW}UVC Gadget${NC} as your camera in Zoom/Teams/etc."
echo ""
read -rp "Reboot now? [y/N] " yn
case "$yn" in
    [Yy]* ) sudo reboot ;;
    * ) info "Remember to reboot before using the webcam." ;;
esac
