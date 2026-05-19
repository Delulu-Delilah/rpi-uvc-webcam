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
| `pi-webcam night [off\|on\|auto]` | Night / low-light mode (NoIR cameras) |
| `pi-webcam overlay [on\|off\|set <text>]` | Text overlay on stream |

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

## Features

- **Two streaming modes** — USB plug-and-play webcam or MJPEG network stream
- **Network stream** has a styled web UI at `http://<pi-ip>:8080` with snapshot endpoint (`/snapshot.jpg`)
- **Camera rotation** — 0°, 180°, horizontal flip, vertical flip
- **Image controls** — brightness, contrast, saturation
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
