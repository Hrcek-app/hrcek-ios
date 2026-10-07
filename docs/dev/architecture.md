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
