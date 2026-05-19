#!/usr/bin/env python3
"""Pi Webcam — MJPEG Network Streaming Server.

Serves a live camera feed over HTTP using picamera2.
Configuration is read from /etc/rpi-webcam.conf.
"""

import io
import socketserver
from http import server
from threading import Condition

from picamera2 import Picamera2
from picamera2.encoders import MJPEGEncoder
from picamera2.outputs import FileOutput
from libcamera import Transform

# ── Read config ──────────────────────────────────────────────
def read_config(path="/etc/rpi-webcam.conf"):
    cfg = {}
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, _, v = line.partition("=")
                    cfg[k.strip()] = v.strip().strip('"')
    except FileNotFoundError:
        pass
    return cfg

CFG = read_config()
PORT = int(CFG.get("WEBCAM_NETWORK_PORT", "8080"))
HFLIP = CFG.get("WEBCAM_HFLIP", "0") == "1"
VFLIP = CFG.get("WEBCAM_VFLIP", "0") == "1"
DEVICE_NAME = CFG.get("WEBCAM_PRODUCT", "Pi Webcam")

# Pick resolution: use the highest enabled
if CFG.get("WEBCAM_RES_1080P", "1") == "1":
    WIDTH, HEIGHT = 1920, 1080
elif CFG.get("WEBCAM_RES_720P", "1") == "1":
    WIDTH, HEIGHT = 1280, 720
else:
    WIDTH, HEIGHT = 640, 480

# ── HTML page ────────────────────────────────────────────────
PAGE = f"""\
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{DEVICE_NAME}</title>
<style>
  * {{ margin:0; padding:0; box-sizing:border-box; }}
  body {{
    font-family: 'Inter', 'Segoe UI', system-ui, sans-serif;
    background: #0f0f14;
    color: #e0e0e6;
    display: flex;
    flex-direction: column;
    align-items: center;
    min-height: 100vh;
    padding: 2rem;
  }}
  h1 {{
    font-size: 1.4rem;
    font-weight: 600;
    margin-bottom: 1rem;
    color: #a8b4ff;
    letter-spacing: 0.02em;
  }}
  h1 span {{ font-size: 1.6rem; margin-right: 0.4rem; }}
  .stream-container {{
    background: #1a1a24;
    border: 1px solid #2a2a3a;
    border-radius: 12px;
    overflow: hidden;
    box-shadow: 0 8px 32px rgba(0,0,0,0.5);
    max-width: 960px;
    width: 100%;
  }}
  img {{
    display: block;
    width: 100%;
    height: auto;
  }}
  .info {{
    display: flex;
    gap: 2rem;
    padding: 0.8rem 1.2rem;
    font-size: 0.8rem;
    color: #888;
    border-top: 1px solid #2a2a3a;
  }}
  .info span {{ color: #aab4ff; }}
</style>
</head>
<body>
  <h1><span>📷</span> {DEVICE_NAME}</h1>
  <div class="stream-container">
    <img src="/stream.mjpg" alt="Live camera feed">
    <div class="info">
      <div>Resolution: <span>{WIDTH}×{HEIGHT}</span></div>
      <div>Format: <span>MJPEG</span></div>
      <div>Rotation: <span>{"180°" if HFLIP and VFLIP else "H-Flip" if HFLIP else "V-Flip" if VFLIP else "None"}</span></div>
    </div>
  </div>
</body>
</html>"""


# ── Streaming output ─────────────────────────────────────────
class StreamingOutput(io.BufferedIOBase):
    def __init__(self):
        self.frame = None
        self.condition = Condition()

    def write(self, buf):
        with self.condition:
            self.frame = buf
            self.condition.notify_all()


# ── HTTP handler ─────────────────────────────────────────────
class StreamingHandler(server.BaseHTTPRequestHandler):
    output = None

    def do_GET(self):
        if self.path == "/":
            content = PAGE.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)
        elif self.path == "/stream.mjpg":
            self.send_response(200)
            self.send_header("Age", "0")
            self.send_header("Cache-Control", "no-cache, private")
            self.send_header("Pragma", "no-cache")
            self.send_header("Content-Type",
                             "multipart/x-mixed-replace; boundary=FRAME")
            self.end_headers()
            try:
                while True:
                    with self.server.output.condition:
                        self.server.output.condition.wait()
                        frame = self.server.output.frame
                    self.wfile.write(b"--FRAME\r\n")
                    self.send_header("Content-Type", "image/jpeg")
                    self.send_header("Content-Length", str(len(frame)))
                    self.end_headers()
                    self.wfile.write(frame)
                    self.wfile.write(b"\r\n")
            except Exception:
                pass
        else:
            self.send_error(404)

    def log_message(self, format, *args):
        pass  # suppress access logs


class StreamingServer(socketserver.ThreadingMixIn, server.HTTPServer):
    allow_reuse_address = True
    daemon_threads = True

    def __init__(self, addr, handler, output):
        self.output = output
        super().__init__(addr, handler)


# ── Main ─────────────────────────────────────────────────────
def main():
    picam2 = Picamera2()
    transform = Transform(hflip=HFLIP, vflip=VFLIP)
    config = picam2.create_video_configuration(
        main={"size": (WIDTH, HEIGHT)},
        transform=transform,
    )
    picam2.configure(config)

    output = StreamingOutput()
    picam2.start_recording(MJPEGEncoder(), FileOutput(output))

    import socket
    ip = socket.gethostbyname(socket.gethostname())
    print(f"📷 {DEVICE_NAME} streaming at http://{ip}:{PORT}")
    print(f"   Resolution: {WIDTH}x{HEIGHT}  Transform: hflip={HFLIP} vflip={VFLIP}")

    try:
        srv = StreamingServer(("", PORT), StreamingHandler, output)
        srv.serve_forever()
    finally:
        picam2.stop_recording()


if __name__ == "__main__":
    main()
