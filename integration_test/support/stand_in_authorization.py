# A stand-in authorization service for measuring Porelo's Authorize, on loopback only.
# Device flow (RFC 8628) and the code flow's token exchange, with nothing real behind them.
# Started with "lasting" after the port, it grants as GitHub's OAuth apps do: an access token with
# no refresh token and no expiry, which only the person can end at the service.
import json, sys, urllib.parse
from http.server import BaseHTTPRequestHandler, HTTPServer

state = {"approved": False, "refused": False, "log": []}
LASTING = len(sys.argv) > 2 and sys.argv[2] == "lasting"

class H(BaseHTTPRequestHandler):
    def _json(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data))); self.end_headers(); self.wfile.write(data)
    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path
        state["log"].append("GET " + path)
        if path == "/approve": state["approved"] = True; return self._json(200, {"ok": True})
        if path == "/refuse": state["refused"] = True; return self._json(200, {"ok": True})
        if path == "/log": return self._json(200, state["log"])
        return self._json(200, {"page": "decide here"})
    def do_POST(self):
        path = urllib.parse.urlparse(self.path).path
        length = int(self.headers.get("Content-Length", 0))
        form = urllib.parse.parse_qs(self.rfile.read(length).decode())
        state["log"].append("POST " + path + " " + ",".join(sorted(form.keys())))
        port = self.server.server_address[1]
        if path == "/device":
            return self._json(200, {"device_code": "dev-1", "user_code": "WDJB-MJHT",
                "verification_uri": f"http://127.0.0.1:{port}/activate",
                "verification_uri_complete": f"http://127.0.0.1:{port}/activate?user_code=WDJB-MJHT",
                "expires_in": 600, "interval": 1})
        if path == "/token":
            if state["refused"]: return self._json(400, {"error": "access_denied"})
            if not state["approved"] and form.get("grant_type", [""])[0].endswith("device_code"):
                return self._json(400, {"error": "authorization_pending"})
            if LASTING:
                return self._json(200, {"access_token": "standin-lasting", "token_type": "bearer", "scope": "read"})
            return self._json(200, {"access_token": "standin-token", "token_type": "Bearer",
                "expires_in": 3600, "refresh_token": "standin-refresh"})
        if path == "/revoke": return self._json(200, {})
        return self._json(404, {"error": "not_found"})
    def log_message(self, *a): pass

HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
