#!/usr/bin/env python3
# Serves this folder with the cross-origin isolation headers that Vosk's WASM
# (SharedArrayBuffer) and Godot's threaded web export require.
#   python3 serve.py            -> http://localhost:8000/webgamev1.html
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import sys, os

# Always serve THIS script's folder, no matter where it's launched from.
os.chdir(os.path.dirname(os.path.abspath(__file__)))

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8000

class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        super().end_headers()

    # .wasm needs the right MIME for streaming compile.
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm"}

if __name__ == "__main__":
    print("Serving %s on http://localhost:%d  (COOP/COEP on)" % (".", PORT))
    ThreadingHTTPServer(("", PORT), Handler).serve_forever()
