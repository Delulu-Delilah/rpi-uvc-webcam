# 🎥 Raspberry Pi USB Webcam

Turn your Raspberry Pi + Camera Module into a **plug-and-play USB webcam** or **network MJPEG streamer**.

Based on the [official Raspberry Pi tutorial](https://www.raspberrypi.com/tutorials/plug-and-play-raspberry-pi-usb-webcam/).

> **⚠️ Required OS: Raspberry Pi OS (Legacy) Lite**
>
> In Raspberry Pi Imager, select:
> **Raspberry Pi OS (Other)** → **Raspberry Pi OS (Legacy) Lite**
>
> This is the Bullseye-based headless image. The standard Bookworm release has not been officially tested with the UVC gadget workflow.

## Install

SSH into your Pi, then run:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/Delulu-Delilah/rpi-uvc-webcam/main/install-rpi-webcam.sh)
```

An interactive wizard walks you through:
- Pi model & camera selection
- Device name (shown in Zoom/Teams)
- Resolution selection (480p / 720p / 1080p)
- **Streaming mode** — USB webcam or network MJPEG
- **Camera rotation** — 0°, 180°, H-flip, V-flip
- **Auto-updates** — opt-in weekly checks

## Management CLI

After installation, use `pi-webcam` to manage everything:

```
pi-webcam status                  Show status
pi-webcam mode [usb|network]      Switch streaming mode
pi-webcam rotate [0|180|hflip|vflip]  Set camera rotation
pi-webcam update                  Check for updates
pi-webcam update --auto-on        Enable weekly auto-updates
pi-webcam update --auto-off       Disable auto-updates
pi-webcam config                  Re-run setup wizard
pi-webcam logs [N]                Show last N service log lines
```

## SSH Status Banner

Every SSH login shows a live status box:

```
  ┌────────────────────────────────────────────────┐
  │  📷  Pi Webcam                                 │
  ├────────────────────────────────────────────────┤
  │  Service   ·····  ● Active                     │
  │  Mode      ·····  USB Webcam                   │
  │  Camera    ·····  Camera Module 3              │
  │  Device    ·····  "Pi Webcam"                  │
  │  Formats   ·····  480p 720p 1080p              │
  │  Rotation  ·····  None                         │
  │  Updates   ·····  Auto (weekly)                │
  │                                                │
  │  Run pi-webcam for options                     │
  └────────────────────────────────────────────────┘
```

## Streaming Modes

| Mode | How it works | Access |
|------|-------------|--------|
| **USB** (default) | Pi acts as a plug-and-play UVC webcam | Plug USB cable into computer |
| **Network** | MJPEG stream served over HTTP | `http://<pi-ip>:8080` in any browser |

Switch anytime: `pi-webcam mode`

## Uninstall

```bash
bash <(curl -sSL https://raw.githubusercontent.com/Delulu-Delilah/rpi-uvc-webcam/main/uninstall-rpi-webcam.sh)
```

## Prerequisites

| Item | Notes |
|------|-------|
| Raspberry Pi (Zero 2 W, Zero W, Pi 4, Pi 5) | OTG-capable models for USB mode |
| Raspberry Pi Camera Module | v2, v3, HQ, or Global Shutter |
| microSD card | Flashed with **Raspberry Pi OS (Legacy) Lite** — see note above |
| SSH + Wi-Fi | Configured during Imager setup |

## License

Provided as-is. [uvc-gadget](https://gitlab.freedesktop.org/camera/uvc-gadget) has its own license.
