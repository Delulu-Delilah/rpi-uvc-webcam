# 🎥 Raspberry Pi USB Webcam

Turn your Raspberry Pi + Camera Module into a **plug-and-play USB webcam** or **network MJPEG streamer**.

Based on the [official Raspberry Pi tutorial](https://www.raspberrypi.com/tutorials/plug-and-play-raspberry-pi-usb-webcam/).

> **⚠️ Required: Raspberry Pi OS Lite (headless)**
>
> In Raspberry Pi Imager, choose any OS option ending in **"Lite"** — this is the headless version with no desktop environment. Both the Legacy (Bullseye) and standard (Bookworm) Lite images are supported.

## Install

```bash
bash <(curl -sSL https://raw.githubusercontent.com/Delulu-Delilah/rpi-uvc-webcam/main/install-rpi-webcam.sh)
```

## Uninstall

```bash
bash <(curl -sSL https://raw.githubusercontent.com/Delulu-Delilah/rpi-uvc-webcam/main/uninstall-rpi-webcam.sh)
```

## Management CLI — `pi-webcam`

### Streaming
| Command | Description |
|---------|-------------|
| `pi-webcam status` | Show current status |
| `pi-webcam mode [usb\|network]` | Switch streaming mode |
| `pi-webcam test` | Capture a test image to verify camera |

### Camera
| Command | Description |
|---------|-------------|
| `pi-webcam rotate [0\|180\|hflip\|vflip]` | Set camera rotation |
| `pi-webcam image [brightness\|contrast\|saturation\|reset] [val]` | Image adjustments |
| `pi-webcam awb [auto\|incandescent\|tungsten\|fluorescent\|indoor\|daylight\|cloudy]` | White-balance preset |
| `pi-webcam awb manual <red> <blue>` | Manual colour gains (overrides auto) |
| `pi-webcam denoise [off\|fast\|high\|minimal]` | Noise reduction strength |
| `pi-webcam ae [normal\|short\|long\|custom]` | Auto-exposure profile |
| `pi-webcam ae metering [centre\|spot\|matrix]` | Auto-exposure metering area |
| `pi-webcam night [off\|on\|auto]` | Night / low-light mode (NoIR cameras) |
| `pi-webcam overlay [on\|off\|set <text>]` | Text overlay on stream |

### Tuning a webcam for recording
Most YouTube-style webcam fixes are a one-liner via SSH:

```bash
# Fix the green/yellow cast from ceiling lights
pi-webcam awb fluorescent

# Tame noise in dim rooms
pi-webcam denoise high

# Stop overexposure under bright lights
pi-webcam ae short

# Manual white balance once you know your room
pi-webcam awb manual 1.8 1.2
```

All four take effect on the next service restart, which `pi-webcam`
handles automatically. No reboot required.

### Capture
| Command | Description |
|---------|-------------|
| `pi-webcam timelapse [start\|stop\|status]` | Timelapse capture to SD card |

### Network
| Command | Description |
|---------|-------------|
| `pi-webcam auth [set\|off]` | Password-protect the network stream |
| `pi-webcam wifi [status\|connect]` | WiFi management |
| `pi-webcam tailscale` | Tailscale VPN status & remote access |

### System
| Command | Description |
|---------|-------------|
| `pi-webcam update [--auto-on\|--auto-off]` | Check for updates / toggle auto-updates |
| `pi-webcam config` | Re-run setup wizard |
| `pi-webcam diag` | Full diagnostics report |
| `pi-webcam backup [path]` | Backup configuration |
| `pi-webcam restore [path]` | Restore configuration |
| `pi-webcam logs [N]` | View last N service log lines |

## Which settings apply in which mode

Settings live in `/etc/rpi-webcam.conf`. Some are read by the network MJPEG
server (Picamera2 controls) and some by the USB gadget script. The table
below documents what currently affects the live stream per mode.

| Setting | `WEBCAM_*` key | USB mode | Network mode |
|---------|----------------|----------|--------------|
| Streaming mode | `WEBCAM_MODE` | n/a | n/a |
| Device name | `WEBCAM_PRODUCT` | On reboot | n/a |
| Advertised resolutions | `WEBCAM_RES_480P` / `720P` / `1080P` | On reboot | On service restart (picks highest) |
| USB IDs | `WEBCAM_VID` / `WEBCAM_PID` | On reboot | n/a |
| Rotation / flip | `WEBCAM_HFLIP` / `WEBCAM_VFLIP` | On service restart (patched `uvc-gadget`) | On service restart |
| Brightness / contrast / saturation | `WEBCAM_BRIGHTNESS` / `WEBCAM_CONTRAST` / `WEBCAM_SATURATION` | On service restart (patched `uvc-gadget`) | On service restart |
| White balance | `WEBCAM_AWB_MODE` / `WEBCAM_AWB_RED_GAIN` / `WEBCAM_AWB_BLUE_GAIN` | On service restart (patched `uvc-gadget`) | On service restart |
| Noise reduction | `WEBCAM_NOISE_MODE` | On service restart (patched `uvc-gadget`) | On service restart |
| Auto-exposure | `WEBCAM_AE_MODE` / `WEBCAM_AE_METERING` | On service restart (patched `uvc-gadget`) | On service restart |
| Night mode | `WEBCAM_NIGHT_MODE` | **Stored only** (long-exposure profile is network-only) | On service restart |
| Text overlay | `WEBCAM_OVERLAY_ENABLED` / `WEBCAM_OVERLAY_TEXT` | **Stored only** (USB gadget cannot composite text) | On service restart |
| Network port / auth | `WEBCAM_NETWORK_PORT` / `WEBCAM_AUTH_USER` / `WEBCAM_AUTH_HASH` | n/a | On service restart |
| Timelapse | `WEBCAM_TIMELAPSE_INTERVAL` / `WEBCAM_TIMELAPSE_DIR` | Read when `pi-webcam timelapse start` runs | Same |
| Auto-update | `WEBCAM_AUTO_UPDATE` | Read by the weekly timer | Same |

> The installer applies a small patch to `uvc-gadget` at build time so the
> USB pipeline honours libcamera controls (white balance, denoise, exposure,
> rotation, brightness/contrast/saturation). See
> [`patches/uvc-gadget-pi-webcam-controls.patch`](patches/uvc-gadget-pi-webcam-controls.patch)
> for details.

## Features

- **Two streaming modes** — USB plug-and-play webcam or MJPEG network stream
- **Network stream** has a styled web UI at `http://<pi-ip>:8080` with snapshot endpoint (`/snapshot.jpg`)
- **Camera rotation** — 0°, 180°, horizontal flip, vertical flip
- **Image controls** — brightness, contrast, saturation
- **White balance** — auto presets (incandescent, fluorescent, daylight, etc.) or manual colour gains
- **Noise reduction** — libcamera fast / high-quality / minimal modes
- **Auto-exposure** — normal / short / long profiles with centre / spot / matrix metering
- **Text overlay** — timestamp, hostname, or custom text on the stream
- **Night mode** — optimized exposure for low-light / NoIR cameras
- **Timelapse** — periodic captures saved to SD card
- **Password protection** — HTTP basic auth on network stream
- **QR code** — shown in terminal when switching to network mode
- **Auto-updates** — opt-in weekly checks via systemd timer
- **SSH status banner** — live camera/service status on every login
- **Diagnostics** — one-command troubleshooting dump
- **WiFi management** — change networks without reflashing
- **Tailscale** — remote access guidance

## Prerequisites

| Item | Notes |
|------|-------|
| Raspberry Pi (Zero 2 W, Zero W, Pi 4, Pi 5) | OTG-capable models for USB mode |
| Raspberry Pi Camera Module | v2, v3, HQ, or Global Shutter |
| microSD card | Flashed with **Raspberry Pi OS Lite** (any version) — no desktop |
| SSH + Wi-Fi | Configured during Imager setup |

## License

Provided as-is. [uvc-gadget](https://gitlab.freedesktop.org/camera/uvc-gadget) has its own license.
