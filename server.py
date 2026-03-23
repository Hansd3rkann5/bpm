#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import time
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


START_TIME = time.time()
STARTED_AT = datetime.now(timezone.utc).isoformat()
REQUEST_COUNTS = {
    "total": 0,
    "index": 0,
    "status_checks": 0,
}


class AppHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, directory: str | None = None, **kwargs):
        super().__init__(*args, directory=directory, **kwargs)

    def _status_payload(self) -> dict:
        return {
            "app": "water-bpm-tapper",
            "status": "running",
            "started_at_utc": STARTED_AT,
            "uptime_seconds": round(time.time() - START_TIME, 2),
            "requests": REQUEST_COUNTS,
            "pid": os.getpid(),
        }

    def _send_json(self, payload: dict, status: HTTPStatus = HTTPStatus.OK) -> None:
        data = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self) -> None:
        REQUEST_COUNTS["total"] += 1

        if self.path == "/api/health":
            self._send_json({"ok": True, "timestamp_utc": datetime.now(timezone.utc).isoformat()})
            return

        if self.path == "/api/status":
            REQUEST_COUNTS["status_checks"] += 1
            self._send_json(self._status_payload())
            return

        if self.path == "/status":
            REQUEST_COUNTS["status_checks"] += 1
            html = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>App Status</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 0; background: #0d1f2d; color: #e9f6ff; }
    main { max-width: 760px; margin: 3rem auto; padding: 1rem; }
    h1 { margin-top: 0; font-size: 1.6rem; }
    .card { background: #163248; border: 1px solid #2f5976; border-radius: 12px; padding: 1rem; }
    pre { margin: 0; white-space: pre-wrap; word-break: break-word; font-size: 0.95rem; }
    .meta { margin: 1rem 0; color: #b9d8ec; font-size: 0.95rem; }
    a { color: #8dd5ff; text-decoration: none; }
  </style>
</head>
<body>
  <main>
    <h1>Water BPM Tapper Status</h1>
    <p class="meta">Auto-refreshes every 2 seconds. <a href="/">Open app</a></p>
    <div class="card"><pre id="status">Loading...</pre></div>
  </main>
  <script>
    async function refresh() {
      try {
        const res = await fetch('/api/status', { cache: 'no-store' });
        const json = await res.json();
        document.getElementById('status').textContent = JSON.stringify(json, null, 2);
      } catch (err) {
        document.getElementById('status').textContent = 'Failed to load status: ' + err;
      }
    }
    refresh();
    setInterval(refresh, 2000);
  </script>
</body>
</html>
"""
            data = html.encode("utf-8")
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(data)
            return

        if self.path in ("/", "/index.html"):
            REQUEST_COUNTS["index"] += 1

        super().do_GET()


def run_server(host: str, port: int, directory: Path) -> None:
    handler = lambda *args, **kwargs: AppHandler(*args, directory=str(directory), **kwargs)
    server = ThreadingHTTPServer((host, port), handler)
    print(f"Serving {directory} at http://{host}:{port}")
    print(f"App:    http://{host}:{port}/")
    print(f"Status: http://{host}:{port}/status")
    server.serve_forever()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Serve the BPM app with status endpoints.")
    parser.add_argument("--host", default="127.0.0.1", help="Host interface to bind (default: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=8000, help="Port to bind (default: 8000)")
    parser.add_argument(
        "--dir",
        default=".",
        help="Directory to serve (default: current directory)",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    run_server(args.host, args.port, Path(args.dir).resolve())
