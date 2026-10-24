#!/usr/bin/env python3
"""假 WLED 设备：给 `tool/shots/main.dart` 的视觉验收提供一台"在线设备"。

模拟器与主机共用网络栈，所以模拟器里的 `127.0.0.1:8099` 就是主机上的本进程。

    python3 tool/shots/mock_wled.py 8099 /tmp/mock_wled.log

实现 `/json`、`/json/state`（GET/POST）、`/json/info`、`/json/eff`、`/json/pal`、
`/json/fxdata`、`/presets.json`。POST 会真的改动内存里的 state，因此"点开关、
拖亮度"截图反映的是设备回报的状态，而不是静态假图。
"""

import base64
import hashlib
import json
import struct
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

EFFECTS = [
    "Solid", "Blink", "Breathe", "Wipe", "Wipe Random", "Random Colors",
    "Sweep", "Dynamic", "Colorloop", "Rainbow", "Scan", "Dual Scan",
    "Fade", "Theater", "Theater Rainbow", "Running", "Saw", "Twinkle",
    "Dissolve", "Dissolve Rnd", "Sparkle", "Sparkle Dark", "Sparkle+",
    "Strobe", "Strobe Rainbow", "Mega Strobe", "Blink Rainbow", "Android",
    "Chase", "Chase Random", "Chase Rainbow", "Chase Flash",
    "Chase Flash Rnd", "Rainbow Runner", "Colorful", "Traffic Light",
    "Sweep Random", "Chase 2", "Aurora", "Stream", "Scanner", "Lighthouse",
    "Fireworks", "Rain", "Merry Christmas", "Fire Flicker", "Gradient",
    "Loading", "Police", "Police All", "Two Dots", "Two Areas", "Circus",
    "Halloween", "Tri Chase", "Tri Wipe", "Tri Fade", "Lightning",
    "ICU", "Multi Comet", "Scanner Dual", "Stream 2", "Oscillate",
    "Pride 2015", "Juggle", "Palette", "Fireworks Starburst",
    "Fireworks 1D", "Bouncing Balls", "Sinelon", "Sinelon Dual",
    "Sinelon Rainbow", "Popcorn", "Drip", "Plasma", "Percent",
    "Ripple Rainbow", "Heartbeat", "Pacifica", "Candle", "Starburst",
    "Glitter", "Sunrise", "Phased", "Twinklefox", "Twinklecat",
    "Halloween Eyes", "Solid Pattern", "Solid Pattern Tri", "Spots",
    "Spots Fade", "Glitter Sweep", "DNA", "DNA Spiral", "Vortex",
]

PALETTES = [
    "Default", "Random Cycle", "Primary Color", "Based on Primary",
    "Set Colors", "Based on Set", "Party", "Cloud", "Lava", "Ocean",
    "Forest", "Rainbow", "Rainbow Bands", "Sunset", "Rivendell",
    "Breeze", "Red & Blue", "Yellowout", "Analogous", "Splash",
    "Pastel", "Sunset 2", "Beach", "Vintage", "Departure", "Landscape",
    "Beech", "Sherbet", "Hult", "Hult 64", "Drywet", "Jul", "Grintage",
    "Rewhi", "Tertiary", "Fire", "Ice", "Cyane", "Light Pink", "Autumn",
    "Magenta", "Magred", "Yelmag", "Yelblu", "Orange & Teal", "Tiamat",
    "April Night", "Orangery", "C9", "C9 2", "C9 Aurora", "C9 Halloween",
    "C9 Christmas", "C9 Ice", "C9 Plasma", "C9 Forest", "C9 Party",
]

STATE = {
    "on": True,
    "bri": 168,
    "transition": 7,
    "ps": -1,
    "pl": -1,
    "lor": 0,
    "mainseg": 0,
    "nl": {"on": False, "dur": 60, "fade": True, "mode": 1, "tbri": 0},
    "udpn": {"send": False, "recv": True},
    "seg": [
        {
            "id": 0, "start": 0, "stop": 60, "len": 60, "grp": 1, "spc": 0,
            "on": True, "frz": False, "bri": 255, "cct": 127,
            "col": [[255, 148, 40], [0, 0, 0], [0, 0, 0]],
            "fx": 2, "sx": 128, "ix": 128, "pal": 0, "sel": True,
            "rev": False, "mi": False, "rY": False, "mY": False,
            "tp": False, "o1": False, "o2": False, "o3": False,
            "n": "主灯带",
        },
        {
            "id": 1, "start": 60, "stop": 120, "len": 60, "grp": 1, "spc": 0,
            "on": True, "frz": False, "bri": 200, "cct": 127,
            "col": [[80, 200, 255], [0, 0, 0], [0, 0, 0]],
            "fx": 9, "sx": 128, "ix": 128, "pal": 6, "sel": False,
            "rev": False, "mi": False, "rY": False, "mY": False,
            "tp": False, "o1": False, "o2": False, "o3": False,
            "n": "背景氛围",
        },
    ],
}

INFO = {
    "ver": "0.14.4",
    "vid": 2310160,
    "leds": {
        "count": 120,
        "rgbw": False,
        "wv": False,
        "maxpwr": 8500,
        "pwr": 3120,
        "maxseg": 16,
        "seglc": [60, 60],
        "lc": 1,
        "fps": 42,
        "cct": True,
        "matrix": None,
    },
    "name": "WLED Studio",
    "udpport": 21324,
    "live": False,
    "fxcount": len(EFFECTS),
    "palcount": len(PALETTES),
    "arch": "esp32",
    "freeheap": 148320,
    "uptime": 918273,
    "brand": "WLED",
    "product": "FOSS",
    "mac": "AA:BB:CC:11:22:33",
    "wifi": {"bssid": "24:0A:C4:11:22:33", "rssi": -52, "signal": 82, "channel": 6},
}

PRESETS = {
    "1": {"n": "晨光", "on": True, "bri": 200, "seg": [{"col": [[255, 170, 90]]}]},
    "2": {"n": "夜读", "on": True, "bri": 90, "seg": [{"col": [[255, 180, 120]]}]},
    "3": {"n": "深海", "on": True, "bri": 150, "seg": [{"col": [[40, 120, 200]]}]},
    "4": {"n": "派对", "on": True, "bri": 255, "seg": [{"col": [[255, 0, 120]]}]},
}


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _send(self, payload, code=200):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    # ---- 最小 WebSocket：WLED 的实时推送在 /ws，握手后每 2 秒推一次 state ----

    def _ws_frame(self, text):
        payload = text.encode()
        header = bytearray([0x81])  # FIN + text
        n = len(payload)
        if n < 126:
            header.append(n)
        elif n < 65536:
            header.append(126)
            header += struct.pack(">H", n)
        else:
            header.append(127)
            header += struct.pack(">Q", n)
        self.wfile.write(bytes(header) + payload)
        self.wfile.flush()

    def _ws_serve(self):
        key = self.headers.get("Sec-WebSocket-Key")
        if not key:
            self._send({"error": "no key"}, 400)
            return
        accept = base64.b64encode(
            hashlib.sha1(
                (key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()
            ).digest()
        ).decode()
        self.send_response(101)
        self.send_header("Upgrade", "websocket")
        self.send_header("Connection", "Upgrade")
        self.send_header("Sec-WebSocket-Accept", accept)
        self.end_headers()
        self.close_connection = True
        try:
            while True:
                self._ws_frame(json.dumps(STATE))
                time.sleep(2)
        except Exception:
            pass

    def _log(self, line):
        with open(LOG, "a") as f:
            f.write(line + "\n")

    def do_GET(self):
        path = self.path.split("?")[0]
        self._log(f"GET {self.path}")
        if path == "/ws":
            self._ws_serve()
        elif path == "/json":
            self._send({"state": STATE, "info": INFO})
        elif path == "/json/state":
            self._send(STATE)
        elif path == "/json/info":
            self._send(INFO)
        elif path == "/json/eff":
            self._send(EFFECTS)
        elif path == "/json/pal":
            self._send(PALETTES)
        elif path == "/json/fxdata":
            self._send([";".join(EFFECTS)])
        elif path == "/presets.json":
            self._send(PRESETS)
        else:
            self._send({"error": "not found", "path": path}, 404)

    def do_POST(self):
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b"{}"
        self._log(f"POST {self.path} {raw.decode(errors='replace')}")
        try:
            patch = json.loads(raw or b"{}")
        except json.JSONDecodeError:
            patch = {}
        for key, value in patch.items():
            if key == "seg" and isinstance(value, list):
                continue  # 分段补丁过于复杂，验收不需要
            STATE[key] = value
        self._send({"success": True})

    def log_message(self, fmt, *args):  # 静默，只写自己的日志
        pass


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8099
    LOG = sys.argv[2] if len(sys.argv) > 2 else "/tmp/mock_wled.log"
    open(LOG, "w").close()
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
