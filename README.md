# 🎥 Raspberry Pi USB Webcam — One-Line Installer

Turn your Raspberry Pi + Camera Module into a **plug-and-play USB webcam** for Zoom, Teams, Skype, and more.

Based on the [official Raspberry Pi tutorial](https://www.raspberrypi.com/tutorials/plug-and-play-raspberry-pi-usb-webcam/).

## Prerequisites

| Item | Notes |
|------|-------|
| Raspberry Pi Zero 2 W (or any OTG-capable Pi) | USB OTG required for single-cable operation |
| Raspberry Pi Camera Module (v2 or v3) | Plus the correct ribbon cable for your Pi |
| microSD card | Flashed with **Raspberry Pi OS (Legacy) Lite** via Raspberry Pi Imager |
| SSH enabled | Configured during Imager setup |
| Wi-Fi configured | Configured during Imager setup |

## Install

SSH into your Pi, then run:

```bash
curl -sSL https://raw.githubusercontent.com/<YOUR_USERNAME>/rpi-uvc-webcam/main/install-rpi-webcam.sh | bash
```

Or clone and run manually:

```bash
git clone https://github.com/<YOUR_USERNAME>/rpi-uvc-webcam.git
cd rpi-uvc-webcam
chmod +x install-rpi-webcam.sh
./install-rpi-webcam.sh
```

## What the installer does

1. **Updates** all system packages (`apt update && apt full-upgrade`)
2. **Enables** the `dwc2` USB OTG overlay in `/boot/firmware/config.txt`
3. **Installs** build dependencies (`git`, `meson`, `libcamera-dev`, `libjpeg-dev`)
4. **Clones & builds** [uvc-gadget](https://gitlab.freedesktop.org/camera/uvc-gadget)
5. **Creates** `~/.rpi-uvc-gadget.sh` — the runtime USB gadget configuration script
6. **Registers** the script in `/etc/rc.local` so it starts automatically on every boot
7. **Prompts** you to reboot

## After installation

1. Shut down the Pi: `sudo shutdown -h now`
2. Connect the camera module via the ribbon cable
3. Put everything in a case
4. Plug the Pi into your computer's USB **data** port (not the power-only port on Zero models)
5. Select **"UVC Gadget"** as your camera in your video calling app

## Supported resolutions

| Resolution | Format | Max FPS |
|-----------|--------|---------|
| 640×480 | Uncompressed / MJPEG | 30 |
| 1280×720 | Uncompressed / MJPEG | 30 |
| 1920×1080 | Uncompressed / MJPEG | 15 / 30 |

## License

The installer script is provided as-is. The [uvc-gadget](https://gitlab.freedesktop.org/camera/uvc-gadget) project has its own license.
