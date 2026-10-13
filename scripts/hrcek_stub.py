"""A fake Hrček for UI tests: only what the app calls, answered the way
the real server does (scripts/contract-test checks both)."""

import json
import re
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit

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
    "HRC-CORE-0002": ("The submitted data is not valid.", "Poslani podatki niso veljavni."),
    "HRC-FIELD-0001": ("There is no field with that name.", "Polja s tem imenom ni."),
    "HRC-IMAGE-0005": ("That address points somewhere Hrček will not go.",
                       "Ta naslov kaže nekam, kamor Hrček ne gre."),
}
STATUS = {"HRC-AUTH-0001": 401, "HRC-AUTH-0002": 403, "HRC-AUTH-0003": 401,
          "HRC-AUTH-0004": 401, "HRC-CORE-0003": 404, "HRC-CORE-0002": 422,
          "HRC-FIELD-0001": 422, "HRC-IMAGE-0005": 422}
# What a fresh account starts with, plus one of each other kind.
FIELDS = [{"name": "Priority", "kind": "choice", "options": ["high", "medium", "low"]},
          {"name": "Price", "kind": "number", "options": []},
          {"name": "Shop", "kind": "text", "options": []}]


class Handler(BaseHTTPRequestHandler):
    entries: dict[str, dict] = {}
    # Picture bytes by entry id.
    pictures: dict[int, tuple[bytes, str]] = {}
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
        path = urlsplit(self.path).path
        if path == "/api/fields/":
            if self.authorised():
                self.reply(200, {"items": FIELDS, "count": len(FIELDS)})
        elif path == "/api/labels/":
            if self.authorised():
                self.labels(parse_qs(urlsplit(self.path).query))
        elif re.fullmatch(r"/entries/\d+/image/", path):
            if self.authorised():
                self.picture(int(path.split("/")[2]))
        elif self.path == "/api/health":
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
        elif re.fullmatch(r"/api/entries/\d+/image", self.path):
            if self.authorised():
                self.upload(int(self.path.split("/")[3]))
        else:
            self.fail("HRC-CORE-0003")

    def do_DELETE(self):  # noqa: N802 - the name http.server dispatches to
        if not re.fullmatch(r"/api/entries/\d+/image", self.path):
            return self.fail("HRC-CORE-0003")
        if not self.authorised():
            return None
        entry = self.entry(int(self.path.split("/")[3]))
        if entry is None or entry["image"] is None:
            return self.fail("HRC-CORE-0003")
        entry["image"] = None
        self.pictures.pop(entry["id"], None)
        self.send_response(204)
        self.end_headers()
        return None

    def entry(self, pk):
        return next((e for e in self.entries.values() if e["id"] == pk), None)

    def upload(self, pk):
        entry = self.entry(pk)
        length = int(self.headers.get("Content-Length", 0))
        data = self.rfile.read(length)
        if entry is None or "multipart/form-data" not in self.headers.get("Content-Type", ""):
            return self.fail("HRC-CORE-0003")
        # Not a real multipart parser: the stub only keeps what came.
        self.pictures[pk] = (data, "image/png")
        entry["image"] = {"url": f"/entries/{pk}/image/", "width": 1, "height": 1}
        self.reply(200, entry)

    def picture(self, pk):
        if pk not in self.pictures:
            return self.fail("HRC-CORE-0003")
        data, kind = self.pictures[pk]
        self.send_response(200)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

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

    def labels(self, query):
        # Labels in use, alphabetically ignoring capitals, prefix matched literally.
        prefix = query.get("starts_with", [""])[0].strip().lower()
        names = {tag for entry in self.entries.values() for tag in entry["tags"]}
        matching = sorted((n for n in names if n.lower().startswith(prefix)), key=str.lower)
        self.reply(200, {"items": [{"name": n} for n in matching], "count": len(matching)})

    @staticmethod
    def patched(fields, patch):
        """The server's rules: names match ignoring case, "" clears, the
        rest is kept. Answers the fields, or the error code."""
        fields = dict(fields)
        for sent, value in patch.items():
            field = next((f for f in FIELDS if f["name"].lower() == sent.lower()), None)
            if field is None:
                return "HRC-FIELD-0001"
            value = str(value).strip()
            if value == "":
                fields.pop(field["name"], None)
                continue
            if field["kind"] == "choice" and value not in field["options"]:
                return "HRC-CORE-0002"
            if field["kind"] == "number":
                try:
                    float(value)
                except ValueError:
                    return "HRC-CORE-0002"
            fields[field["name"]] = value
        return fields

    def save(self, body):
        # Like the server: title, notes and tags are replaced; fields and
        # the picture are kept unless named.
        url = body["url"].strip()
        held = self.entries.get(url)
        fields = self.patched(held["fields"] if held else {}, body.get("fields") or {})
        if isinstance(fields, str):
            return self.fail(fields)
        image = held["image"] if held else None
        if body.get("image_url"):
            # Like the server, it will not fetch from this machine.
            if urlsplit(body["image_url"]).hostname in ("localhost", "127.0.0.1", "::1"):
                return self.fail("HRC-IMAGE-0005")
            image = {"url": "/entries/0/image/", "width": 1, "height": 1}
        entry = {"id": held["id"] if held else len(self.entries) + 1, "url": url,
                 "title": body.get("title", ""), "notes": body.get("notes", ""),
                 "tags": sorted(set(body.get("tags", [])), key=str.lower),
                 "fields": fields,
                 "image": image,
                 "created_at": "2026-10-05T10:00:00Z", "updated_at": "2026-10-05T10:00:00Z"}
        if image is not None:
            image["url"] = f"/entries/{entry['id']}/image/"
        self.entries[url] = entry
        self.reply(200 if held else 201, entry)


def serve(port=8765):
    return ThreadingHTTPServer(("127.0.0.1", port), Handler)
