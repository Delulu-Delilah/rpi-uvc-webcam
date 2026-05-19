#!/usr/bin/env python3
"""Pi Webcam — MJPEG Network Streaming Server v3.1"""
import io, os, socket, socketserver, hashlib, base64, time
from datetime import datetime
from http import server
from threading import Condition
from picamera2 import Picamera2
from picamera2.encoders import MJPEGEncoder
from picamera2.outputs import FileOutput
from libcamera import Transform

def read_config(path="/etc/rpi-webcam.conf"):
    cfg = {}
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, _, v = line.partition("=")
                    cfg[k.strip()] = v.strip().strip('"')
    except FileNotFoundError: pass
    return cfg

CFG = read_config()
PORT = int(CFG.get("WEBCAM_NETWORK_PORT", "8080"))
HFLIP = CFG.get("WEBCAM_HFLIP", "0") == "1"
VFLIP = CFG.get("WEBCAM_VFLIP", "0") == "1"
DEVICE_NAME = CFG.get("WEBCAM_PRODUCT", "Pi Webcam")
BRIGHTNESS = float(CFG.get("WEBCAM_BRIGHTNESS", "0.0"))
CONTRAST = float(CFG.get("WEBCAM_CONTRAST", "1.0"))
SATURATION = float(CFG.get("WEBCAM_SATURATION", "1.0"))
AUTH_USER = CFG.get("WEBCAM_AUTH_USER", "")
AUTH_HASH = CFG.get("WEBCAM_AUTH_HASH", "")
OVERLAY_ON = CFG.get("WEBCAM_OVERLAY_ENABLED", "0") == "1"
OVERLAY_FMT = CFG.get("WEBCAM_OVERLAY_TEXT", "%H:%M:%S")
NIGHT_MODE = CFG.get("WEBCAM_NIGHT_MODE", "off")

if CFG.get("WEBCAM_RES_1080P", "1") == "1": WIDTH, HEIGHT = 1920, 1080
elif CFG.get("WEBCAM_RES_720P", "1") == "1": WIDTH, HEIGHT = 1280, 720
else: WIDTH, HEIGHT = 640, 480

# Overlay support
HAS_PIL = False
if OVERLAY_ON:
    try:
        from PIL import Image, ImageDraw, ImageFont
        import numpy as np
        HAS_PIL = True
    except ImportError: pass

ROT_LABEL = "180°" if HFLIP and VFLIP else "H-Flip" if HFLIP else "V-Flip" if VFLIP else "None"
NIGHT_LABEL = NIGHT_MODE.capitalize()

PAGE = f"""\
<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{DEVICE_NAME}</title><style>
*{{margin:0;padding:0;box-sizing:border-box}}
body{{font-family:'Inter','Segoe UI',system-ui,sans-serif;background:#0f0f14;color:#e0e0e6;display:flex;flex-direction:column;align-items:center;min-height:100vh;padding:2rem}}
h1{{font-size:1.4rem;font-weight:600;margin-bottom:1rem;color:#a8b4ff;letter-spacing:.02em}}
h1 span{{font-size:1.6rem;margin-right:.4rem}}
.sc{{background:#1a1a24;border:1px solid #2a2a3a;border-radius:12px;overflow:hidden;box-shadow:0 8px 32px rgba(0,0,0,.5);max-width:960px;width:100%}}
img{{display:block;width:100%;height:auto}}
.info{{display:flex;gap:2rem;padding:.8rem 1.2rem;font-size:.8rem;color:#888;border-top:1px solid #2a2a3a;flex-wrap:wrap}}
.info span{{color:#aab4ff}}
.links{{margin-top:1rem;font-size:.85rem;color:#666}}
.links a{{color:#7a8aff;text-decoration:none}}
.links a:hover{{text-decoration:underline}}
</style></head><body>
<h1><span>📷</span> {DEVICE_NAME}</h1>
<div class="sc"><img src="/stream.mjpg" alt="Live feed">
<div class="info"><div>Resolution: <span>{WIDTH}×{HEIGHT}</span></div>
<div>Rotation: <span>{ROT_LABEL}</span></div>
<div>Night: <span>{NIGHT_LABEL}</span></div></div></div>
<div class="links"><a href="/snapshot.jpg">📸 Snapshot</a></div>
</body></html>"""

class StreamingOutput(io.BufferedIOBase):
    def __init__(self):
        self.frame = None
        self.condition = Condition()
    def write(self, buf):
        with self.condition:
            self.frame = buf
            self.condition.notify_all()

def check_auth(handler):
    if not AUTH_USER: return True
    auth = handler.headers.get("Authorization", "")
    if not auth.startswith("Basic "): return False
    try:
        decoded = base64.b64decode(auth[6:]).decode()
        user, _, pw = decoded.partition(":")
        return user == AUTH_USER and hashlib.sha256(pw.encode()).hexdigest() == AUTH_HASH
    except Exception: return False

class StreamingHandler(server.BaseHTTPRequestHandler):
    def do_GET(self):
        if not check_auth(self):
            self.send_response(401)
            self.send_header("WWW-Authenticate", 'Basic realm="Pi Webcam"')
            self.end_headers()
            return
        if self.path == "/":
            c = PAGE.encode(); self.send_response(200)
            self.send_header("Content-Type","text/html"); self.send_header("Content-Length",str(len(c)))
            self.end_headers(); self.wfile.write(c)
        elif self.path == "/snapshot.jpg":
            with self.server.output.condition:
                self.server.output.condition.wait()
                frame = self.server.output.frame
            self.send_response(200)
            self.send_header("Content-Type","image/jpeg")
            self.send_header("Content-Length",str(len(frame)))
            self.send_header("Cache-Control","no-cache")
            self.end_headers(); self.wfile.write(frame)
        elif self.path == "/stream.mjpg":
            self.send_response(200)
            self.send_header("Cache-Control","no-cache,private")
            self.send_header("Content-Type","multipart/x-mixed-replace; boundary=FRAME")
            self.end_headers()
            try:
                while True:
                    with self.server.output.condition:
                        self.server.output.condition.wait()
                        frame = self.server.output.frame
                    self.wfile.write(b"--FRAME\r\nContent-Type: image/jpeg\r\nContent-Length: "+str(len(frame)).encode()+b"\r\n\r\n")
                    self.wfile.write(frame); self.wfile.write(b"\r\n")
            except Exception: pass
        else: self.send_error(404)
    def log_message(self, *a): pass

class StreamingServer(socketserver.ThreadingMixIn, server.HTTPServer):
    allow_reuse_address = True; daemon_threads = True
    def __init__(self, addr, handler, output):
        self.output = output; super().__init__(addr, handler)

def main():
    picam2 = Picamera2()
    transform = Transform(hflip=HFLIP, vflip=VFLIP)
    config = picam2.create_video_configuration(main={"size":(WIDTH,HEIGHT)}, transform=transform)
    picam2.configure(config)

    controls = {}
    if BRIGHTNESS != 0.0: controls["Brightness"] = BRIGHTNESS
    if CONTRAST != 1.0: controls["Contrast"] = CONTRAST
    if SATURATION != 1.0: controls["Saturation"] = SATURATION
    if NIGHT_MODE == "on":
        controls["ExposureTime"] = 100000
        controls["AnalogueGain"] = 8.0
    elif NIGHT_MODE == "auto":
        controls["AeEnable"] = True
    if controls: picam2.set_controls(controls)

    # Overlay callback
    if OVERLAY_ON and HAS_PIL:
        def apply_overlay(request):
            with MappedArray(request, "main") as m:
                img = Image.fromarray(m.array)
                draw = ImageDraw.Draw(img)
                txt = datetime.now().strftime(OVERLAY_FMT).replace("{hostname}", socket.gethostname())
                draw.text((10, HEIGHT-30), txt, fill=(255,255,255))
                m.array[:] = np.array(img)
        from picamera2 import MappedArray
        picam2.pre_callback = apply_overlay

    output = StreamingOutput()
    picam2.start_recording(MJPEGEncoder(), FileOutput(output))

    ip = socket.gethostbyname(socket.gethostname())
    print(f"📷 {DEVICE_NAME} streaming at http://{ip}:{PORT}")
    if AUTH_USER: print(f"   Auth: enabled (user: {AUTH_USER})")

    try:
        StreamingServer(("", PORT), StreamingHandler, output).serve_forever()
    finally:
        picam2.stop_recording()

if __name__ == "__main__": main()
