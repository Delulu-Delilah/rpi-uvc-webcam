# 🎥 Raspberry Pi USB Webcam — One-Line Installer

Turn your Raspberry Pi + Camera Module into a **plug-and-play USB webcam** for Zoom, Teams, Skype, and more.

Based on the [official Raspberry Pi tutorial](https://www.raspberrypi.com/tutorials/plug-and-play-raspberry-pi-usb-webcam/).

## Prerequisites

| Item | Notes |
|------|-------|
| Raspberry Pi Zero 2 W, Zero W, Pi 4, or Pi 5 | USB OTG required for single-cable operation |
| Raspberry Pi Camera Module (v2 or v3) | Plus the correct ribbon cable for your Pi |
| microSD card | Flashed with **Raspberry Pi OS Lite** (Bullseye or Bookworm) |
| SSH enabled | Configured during Imager setup |
| Wi-Fi configured | Configured during Imager setup |

## Install

SSH into your Pi, then run:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/Delulu-Delilah/rpi-uvc-webcam/main/install-rpi-webcam.sh)
```

An interactive setup wizard will walk you through selecting your hardware and preferences:

```
┌──────────────────────────────────────────────┐
│        📷  Pi Webcam Installer               │
├──────────────────────────────────────────────┤
│                                              │
│  1. Select your Pi model                     │
│  2. Select your camera module                │
│  3. Name your webcam device                  │
│  4. Choose video resolutions                 │
│  5. Confirm & install                        │
│                                              │
└──────────────────────────────────────────────┘
```

## Uninstall

```bash
bash <(curl -sSL https://raw.githubusercontent.com/Delulu-Delilah/rpi-uvc-webcam/main/uninstall-rpi-webcam.sh)
```

## What the installer does

1. **Walks you through** hardware & preference selection via a terminal UI
2. **Saves** your config to `/etc/rpi-webcam.conf`
3. **Updates** all system packages
4. **Enables** the `dwc2` USB OTG overlay
5. **Installs** build dependencies (`git`, `meson`, `libcamera-dev`, `libjpeg-dev`)
6. **Clones & builds** [uvc-gadget](https://gitlab.freedesktop.org/camera/uvc-gadget)
7. **Creates** a config-driven gadget script at `~/.rpi-uvc-gadget.sh`
8. **Installs** an SSH login status banner showing service health at a glance
9. **Creates** a systemd service for automatic startup on boot

## SSH Status Banner

Every time you SSH into your Pi, you'll see a live status display:

```
  ┌────────────────────────────────────────────────┐
  │        📷  Pi Webcam                           │
  ├────────────────────────────────────────────────┤
  │                                                │
  │  Service  ·········  ● Active                  │
  │  Camera   ·········  Camera Module 3           │
  │  Device   ·········  "Pi Webcam"               │
  │  Formats  ·········  480p 720p 1080p           │
  │  USB      ·········  Connected                 │
  │                                                │
  └────────────────────────────────────────────────┘
```

## Reconfigure

Run the installer again to change your settings. It will detect the existing configuration and offer to reconfigure.

## After installation

1. Shut down the Pi: `sudo shutdown -h now`
2. Connect the camera module via the ribbon cable
3. Put everything in a case
4. Plug the Pi into your computer's USB **data** port (not the power-only port on Zero models)
5. Select your webcam name in your video calling app

## Supported resolutions

| Resolution | Format | Max FPS |
|-----------|--------|---------|
| 640×480 | Uncompressed / MJPEG | 30 |
| 1280×720 | Uncompressed / MJPEG | 30 |
| 1920×1080 | Uncompressed / MJPEG | 15 / 30 |

## License

The installer script is provided as-is. The [uvc-gadget](https://gitlab.freedesktop.org/camera/uvc-gadget) project has its own license.
