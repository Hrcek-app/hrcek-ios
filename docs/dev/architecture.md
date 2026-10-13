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
is never stored. A person may instead paste a token they made on the
website; it is checked with `GET /api/auth/me` and stored the same way.

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

## The share extension

`ShareViewController` hands the shared items to `SharedPage`. Safari
first runs `HrcekShare/Preprocess.js` in the page
(`NSExtensionJavaScriptPreprocessingFile`) and hands over only its
answer: the address, the title and every picture the page names in its
head or shows in its body. A picture a lazy loader is still holding
back (an inline or 1×1 placeholder) is read from `data-src` and its
usual variants, the rule the browser extension's harvest follows. Other
browsers hand over a URL item, or text
with an address in it, and sometimes a title; for those, `PagePictures`
reads the page's head for the pictures it names. Either way
`PageCandidate` ranks the pictures: the head's first, then the largest
images; SVG, anything under 100 points a side and duplicates are
dropped, and no more than 60 are kept. `ShareModel` drives the
sheet: it looks the address up, fills `EntryDraft` from the page or
from the entry already saved, and saves the draft through
`EntryService`.

Saving (`POST /api/entries/`) replaces an entry's title, notes and tags,
so the sheet always looks first (`POST /api/entries/lookup`) and shows
what it would replace, and always sends all three in full. `fields` and
`image_url` are left out, which the server reads as "leave as it is".
`fields` is the exception to the replace: the server patches it. The
form gets its fields from `GET /api/fields/` and `FieldInput` sends
every field it showed, an emptied one as `""` to clear it, and never
one it did not show. When the definitions cannot be read the entry's
own keys stand in, so its values stay visible and are sent back as they
were. A choice holding a value the field no longer offers is left out
of the save, which keeps it; sending it would be refused, and sending
`""` would destroy it.

`PictureState` holds the picture choice: the held picture first, then
the page's; whether one is included; which. An entry saved without a
picture starts with none included, so reopening it does not add one.
`PictureSaver` turns the choice into requests. It reads the chosen
picture's bytes from the web itself (`PictureBytes`, no cookies) and
uploads them after the save, because the server will not fetch from
private addresses and signed or referer-checked ones do not answer it.
Only when the bytes cannot be had — over 10 MB, SVG, not a picture, a
failed fetch — does the save carry `image_url` instead. If the server
refuses that address (`HRC-IMAGE-*`) the entry is saved again without
it. Removing a picture is `DELETE /api/entries/{id}/image`, since a
save cannot do it. A picture never fails the entry: its trouble is
reported beside **Saved**.

The picture an entry holds is fetched with the token from its
`image.url` to be shown. The server currently answers that address
only to a signed-in browser and sends a token to its sign-in page; the
sheet then says it has a picture it cannot show. Pictures are decoded
no larger than they are drawn (`PictureLoader`), and nothing is read
from the web further than needed — a page's first megabyte, a
picture's first 10 MB — since a share extension is given little
memory. Reading a page for its pictures happens after the form is
open, so a slow page never keeps it closed. Errors from the web are
logged by code only: their description carries the address.

Tag suggestions come from `GET /api/labels/?starts_with=`, asked
200 ms after typing pauses: the view runs `updateSuggestions()` in a
`.task(id:)` keyed on the text, so each keystroke cancels the previous
wait or request. A failed request shows no suggestions and no error.

If the opening lookup failed for any reason other than `HRC-CORE-0003`,
not found, saving looks again first: an entry found then is shown
instead of written over.

A revoked token (`HRC-AUTH-0004`) clears the stored credentials, and
the sheet asks the person to open the app and sign in.
