#!/bin/bash
# Pi Webcam — Timelapse Capture Script
set -euo pipefail
source /etc/rpi-webcam.conf 2>/dev/null
INTERVAL="${WEBCAM_TIMELAPSE_INTERVAL:-30}"
DIR="${WEBCAM_TIMELAPSE_DIR:-$HOME/timelapse}"
HFLIP="${WEBCAM_HFLIP:-0}"; VFLIP="${WEBCAM_VFLIP:-0}"
CAM=$(command -v rpicam-still &>/dev/null && echo "rpicam-still" || echo "libcamera-still")

mkdir -p "$DIR"
FLAGS="--width 1920 --height 1080 --nopreview -q 90"
[[ "$HFLIP" == "1" ]] && FLAGS+=" --hflip"
[[ "$VFLIP" == "1" ]] && FLAGS+=" --vflip"

echo "Timelapse: interval=${INTERVAL}s dir=${DIR}"
while true; do
    FNAME="${DIR}/tl_$(date +%Y%m%d_%H%M%S).jpg"
    $CAM $FLAGS -o "$FNAME" -t 1500 2>/dev/null && echo "Captured: $FNAME" || echo "Capture failed"
    sleep "$INTERVAL"
done
