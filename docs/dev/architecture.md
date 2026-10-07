# Architecture

## Targets

| Target | What it is |
|---|---|
| `Hrcek` | The app: where people sign in and learn how to save pages |
| `HrcekShare` | The share extension: what runs when a page is shared to Hrček |
| `HrcekUITests` | UI tests, driven in the simulator |
| `HrcekKit` | A local Swift package with everything that is not a view |

The app and the extension are thin: SwiftUI views over models from
HrcekKit. Logic lives in the package for two reasons. Its tests run with
`swift test` on the Mac in seconds, which keeps test-first work fast.
And the extension, a separate process, needs the same code as the app.

## Logging

`Log` in HrcekKit holds one `os.Logger` per area — `app`, `api`,
`auth`, `share`, `ui` — under the subsystem `app.hrcek`. App and
extension share the subsystem so one predicate shows both; see
[debugging](debugging.md).

## Talking to the server

`APIClient` sends JSON to one server and decodes the answer. It adds
the bearer token when it has one, and `Accept-Language` set to the
app's own language, so the server's messages come back in English or
Slovenian to match the screen.

Every failure becomes an `APIError`:

| Case | When |
|---|---|
| `server(status:code:message:)` | The server refused with its error envelope, `{"error": {"code", "message", "details"}}` |
| `transport(URLError.Code)` | The request never got an answer: offline, timed out, no such host |
| `unexpectedResponse(status:)` | An answer that is neither the expected success nor the envelope, such as a proxy's HTML error page |

Code that decides something branches on `APIError.code` — the stable
`HRC-…` codes listed in the backend's `docs/dev/error-codes.md` — never
on the message.

`UserFacingError.message(for:)` turns any error into a sentence for a
person. Server errors show the server's own message, which is already
translated. Everything else — being offline, a bad certificate, an
address that is not a Hrček — has its own text in HrcekKit's catalogue.
An answer without the envelope is judged by its status: 429 means too
many attempts (the backend's rate limit replies that way), 5xx means
the server or a proxy in front of it is in trouble, and only anything
else suggests the address may not be a Hrček.

`ServerAddress` normalises what a person types into the server field:
it adds `https://` when there is no scheme, lowercases the host, drops
trailing slashes, keeps a path (Hrček may be served below one), and
refuses plain `http` except for this machine, because the password
would otherwise travel in the clear.

## Signing in and where credentials live

`AuthService` signs in by trading the email address and password for
an API token (`POST /api/auth/tokens/exchange`), then asks who the
token belongs to (`GET /api/auth/me`). The token is named
"Hrček for iOS (<device name>)" in the person's language, which is how
they recognise this phone on the website's clients page. The password
is never stored.

Server address, token and display name are stored together, as one
Keychain item, by `KeychainCredentialStore`. The item lives in a
shared Keychain access group, so the share extension reads exactly what
the app saved. There is no App Group: nothing else needs sharing.

The group name, `<team prefix>.<bundle prefix>.Hrcek.shared`, is
written into both Info.plists at build time (`HrcekKeychainGroup`) and
granted by `Support/Hrcek.entitlements` and
`Support/HrcekShare.entitlements`. The item is readable after the
phone's first unlock and never leaves the device.

**Signing out only forgets the token on this phone.** The API cannot
revoke a token — by design, a token cannot manage tokens — so the
person removes it on the website's clients page, and the app says so.
