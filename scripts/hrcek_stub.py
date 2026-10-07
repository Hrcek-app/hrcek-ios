"""A fake Hrček for UI tests: only what the app calls, answered the way
the real server does (scripts/contract-test checks both)."""

import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

TOKEN = "hrcek_stub"
PASSWORD = "correct horse"
USERS = {"nina@example.com": "Nina", "unconfirmed@example.com": None}
UNCONFIRMED = {"unconfirmed@example.com"}

MESSAGES = {
    "HRC-AUTH-0001": ("The email address or password is not correct.",
                      "E-poštni naslov ali geslo ni pravilno."),
    "HRC-AUTH-0002": ("Confirm your email address before signing in.",
                      "Pred prijavo potrdite svoj e-poštni naslov."),
    "HRC-AUTH-0003": ("You must sign in to do that.", "Za to dejanje se morate prijaviti."),
    "HRC-AUTH-0004": ("This API token is invalid or has expired.",
                      "Ta API-žeton ni veljaven ali je potekel."),
    "HRC-CORE-0003": ("The requested resource does not exist.", "Zahtevani vir ne obstaja."),
}
STATUS = {"HRC-AUTH-0001": 401, "HRC-AUTH-0002": 403, "HRC-AUTH-0003": 401,
          "HRC-AUTH-0004": 401, "HRC-CORE-0003": 404}


class Handler(BaseHTTPRequestHandler):
    entries: dict[str, dict] = {}
    # Lets a UI test revoke the token the way a person would on the website.
    revoked = False

    def log_message(self, format, *args):  # noqa: A002 - keeps test output quiet
        pass

    def reply(self, status, body):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def fail(self, code):
        english, slovenian = MESSAGES[code]
        language = self.headers.get("Accept-Language", "en")
        message = slovenian if language.startswith("sl") else english
        self.reply(STATUS[code], {"error": {"code": code, "message": message, "details": {}}})

    def body(self):
        length = int(self.headers.get("Content-Length", 0))
        return json.loads(self.rfile.read(length) or b"{}")

    def authorised(self):
        header = self.headers.get("Authorization")
        if header is None:
            self.fail("HRC-AUTH-0003")
            return False
        if header != f"Bearer {TOKEN}" or Handler.revoked:
            self.fail("HRC-AUTH-0004")
            return False
        return True

    def do_GET(self):  # noqa: N802 - the name http.server dispatches to
        if self.path == "/api/health":
            self.reply(200, {"status": "ok", "message": "Service is running."})
        elif self.path == "/api/auth/me":
            if self.authorised():
                self.reply(200, {"email": "nina@example.com", "display_name": "Nina"})
        else:
            self.fail("HRC-CORE-0003")

    def do_POST(self):  # noqa: N802 - the name http.server dispatches to
        if self.path == "/api/auth/tokens/exchange":
            self.exchange(self.body())
        elif self.path == "/stub/revoke":
            Handler.revoked = True
            self.reply(200, {})
        elif self.path == "/api/entries/lookup":
            if self.authorised():
                self.lookup(self.body())
        elif self.path == "/api/entries/":
            if self.authorised():
                self.save(self.body())
        else:
            self.fail("HRC-CORE-0003")

    def exchange(self, body):
        identifier = body.get("identifier", "").strip().lower()
        if identifier not in USERS or body.get("password") != PASSWORD:
            return self.fail("HRC-AUTH-0001")
        if identifier in UNCONFIRMED:
            return self.fail("HRC-AUTH-0002")
        Handler.revoked = False
        self.reply(201, {"id": 1, "name": body.get("name", ""), "token": TOKEN,
                         "created_at": "2026-10-05T10:00:00Z", "expires_at": None})

    def lookup(self, body):
        entry = self.entries.get(body.get("url", ""))
        if entry:
            self.reply(200, entry)
        else:
            self.fail("HRC-CORE-0003")

    def save(self, body):
        url = body["url"]
        existed = url in self.entries
        entry = {"id": len(self.entries) + 1, "url": url, "title": body.get("title", ""),
                 "notes": "", "tags": [], "fields": {}}
        self.entries[url] = entry
        self.reply(200 if existed else 201, entry)


def serve(port=8765):
    return ThreadingHTTPServer(("127.0.0.1", port), Handler)
