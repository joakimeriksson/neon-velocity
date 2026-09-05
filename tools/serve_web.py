#!/usr/bin/env python3
"""Serve build/web with the cross-origin isolation headers a threaded Godot web build needs.
   python3 tools/serve_web.py [port]"""
import sys, http.server, functools, os
class H(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()
    def log_message(self, fmt, *args):
        sys.stderr.write("%s %s\n" % (self.address_string(), fmt % args))
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "web")
port = int(sys.argv[1]) if len(sys.argv) > 1 else 8060
http.server.ThreadingHTTPServer(("127.0.0.1", port), functools.partial(H, directory=root)).serve_forever()
