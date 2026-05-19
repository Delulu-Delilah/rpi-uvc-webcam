#!/bin/bash
# Pi Webcam — Auto-Update Script
# Called by rpi-webcam-update.timer (weekly)

set -euo pipefail

REPO="https://raw.githubusercontent.com/Delulu-Delilah/rpi-uvc-webcam/main"
CONFIG="/etc/rpi-webcam.conf"
LOG_TAG="rpi-webcam-update"

log() { logger -t "$LOG_TAG" "$*"; echo "$*"; }

# Load current version
CURRENT="0.0.0"
[[ -f "$CONFIG" ]] && source "$CONFIG"
CURRENT="${WEBCAM_VERSION:-$CURRENT}"

# Fetch latest version
LATEST=$(curl -sSL --connect-timeout 10 "${REPO}/VERSION" 2>/dev/null | head -1) || {
    log "ERROR: Cannot reach update server."
    exit 1
}

if [[ "$LATEST" == "$CURRENT" ]]; then
    log "Up to date (v${CURRENT})."
    exit 0
fi

log "Update available: v${CURRENT} -> v${LATEST}. Installing..."

TMP=$(mktemp)
trap "rm -f $TMP" EXIT
curl -sSL "${REPO}/install-rpi-webcam.sh" -o "$TMP" || {
    log "ERROR: Failed to download installer."
    exit 1
}

bash "$TMP" --update 2>&1 | while IFS= read -r line; do log "$line"; done

log "Update to v${LATEST} complete."
