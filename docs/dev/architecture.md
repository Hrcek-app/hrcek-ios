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
the app saved. The Keychain holds the credentials and the language. An
App Group, `group.<bundle prefix>.Hrcek.shared`, holds the queue of
saves kept for later (below), because those include pictures of up to
10 MB, which do not belong in a Keychain item. The group name is
written into both Info.plists at build time (`HrcekAppGroup`) and
granted by both entitlements files.

The Keychain group name, `<team prefix>.<bundle prefix>.Hrcek.shared`, is
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
`image.url` to be shown, asking for AVIF: the server sends it only
when `Accept` names it, and WebP otherwise. If the bytes cannot be
had — no network, or
a Hrček from before that address took a token, which answers its
sign-in page — the sheet says it has a picture it cannot show, and
saving leaves it alone. Pictures are decoded no larger than they are
drawn (`PictureLoader`), and nothing is read from the web further
than needed — a page's first megabyte, a picture's first 10 MB —
since a share extension is given little memory. Reading a page for
its pictures happens after the form is open, so a slow page never
keeps it closed. Errors from the web are logged by code only: their
description carries the address.

Tag suggestions come from `GET /api/labels/?starts_with=`, asked
200 ms after typing pauses: the view runs `updateSuggestions()` in a
`.task(id:)` keyed on the text, so each keystroke cancels the previous
wait or request. A failed request shows no suggestions and no error.

If the opening lookup failed for any reason other than `HRC-CORE-0003`,
not found, saving looks again first: an entry found then is shown
instead of written over.

A revoked token (`HRC-AUTH-0004`) clears the stored credentials, and
the sheet asks the person to open the app and sign in.

### When Hrček can't be reached

`ShareModel` decides what an outage means for the sheet (see
[Saves kept for later](#saves-kept-for-later) for the queue itself):

- The opening lookup found Hrček unavailable: `isOffline`, and the form
  says so in place of an error. Saving keeps the entry without trying
  to send it, and the button reads **Save for later**.
- The lookup worked but the save found Hrček unavailable, or the
  second look before writing did: the entry is kept the same way.
- The queue is full: the save is refused with a message and the form
  stays as it was.
- The queue holds a waiting or refused copy of the address for this
  server: the form opens on it (`keptCopy`), and a refused copy shows
  Hrček's message. A held copy (`heldCopy`) is only mentioned: the form
  shows Hrček's entry, since the copy was held because Hrček has one.
  So is a waiting or refused copy when the opening lookup found an
  entry: its sync would hold it, and the sheet must not guess either.
  When the opening lookup found Hrček unavailable, that entry cannot be
  shown, so the held copy opens like a waiting one rather than losing
  its edits; kept again it waits, and its sync looks first.
  A successful save removes the copy the form showed, by its `id`, and
  never a newer one kept meanwhile.

The sheet always saves through the queue's representation: it turns
the draft and the picture choice into a `PendingEntry` and its bytes
(`PendingEntry.Picture.chosen`), then either sends it
(`PendingSync.send`) or keeps it. One path, so a kept copy is later sent
exactly as the direct save would have been, and the picture is read
from the web once. A kept copy left with its picture unchanged keeps
the bytes it already has.

After a successful save the sheet sends what else is waiting
(`syncWaiting`), so saving a page is also when kept pages go. It is
given 10 seconds: `PendingSync.run(…, within:)` cancels the run when
the time is up or when its caller is cancelled, and a cancelled run
ends its request, reports `interrupted` and releases `.sync-lock`. The
view runs it inside `whileAllowed`, which holds
`ProcessInfo.performExpiringActivity` for the sync and cancels it when
iOS says the time is up, because iOS kills a suspended extension that
holds a lock file in the shared container. Nothing else in the
extension runs a sync. The sheet shows "Sending N waiting pages…", then
`SyncResult.summary`.

## Saves kept for later

When Hrček cannot take a save, the share sheet keeps it on the phone
and it is sent later. Only an outage is kept for: `APIError.isUnavailable`
is true for a transport failure, or a 502, 503 or 504 answer with or
without the error envelope (what a reverse proxy says for a stopped
Hrček). Certificate and secure-connection failures are not included: a
certificate the phone distrusts today it distrusts tomorrow, so waiting
fixes nothing. A refused token or invalid data would be refused again,
and keeping the save would only hide that.

`PendingQueue` keeps the saves as files in the App Group container:

```
Pending/<sha256 of the normalised address>/entry.json
Pending/<sha256 of the normalised address>/picture   (only with bytes)
Pending/.incoming/<uuid>/                            (writes in progress)
Pending/.lock  Pending/.sync-lock
```

There are at most 100, and one copy per normalised address (trimmed,
scheme and host lowercased). A copy is identified by its `id`, not by
its address or time: a newer copy at the same address is another copy,
and `remove` and `mark` leave it alone. An entry is written aside in
`.incoming` and moved into place under `.lock`, so no reader sees half
of one. Nothing of an entry outlives its place: removing it deletes its
whole directory, replacing it drops an old picture, and opening the
queue sweeps staging older than a minute (a younger one may be the
other process writing) and entries with no `entry.json` or one that
is not an entry; a file that merely fails to be read stays. The directory
is excluded from backup, so a restore onto another phone cannot send
saves twice, and is protected until first unlock, the iOS default.

`PendingSync.run` sends the waiting copies meant for the signed-in
server, oldest first, one at a time, each read again just before it is
handled. For each it looks the address up first. If Hrček has the
address already, the copy is not sent over it: it is marked `held` for a
person to decide, unless Hrček's entry is the copy verbatim (same
title, notes and tags in any case or order), which means an earlier
sync was cut off after Hrček took it, so the copy is simply removed.
Otherwise it is sent like a direct save (`PendingSync.send`, over
`PictureSaver`). A refusal with Hrček's error envelope marks the copy
`refused` with Hrček's own message; held and refused copies are never
retried. The first outage, refused token or failed lookup ends the run
with the rest untouched, and a cancelled run reports `interrupted`.
Only one sync runs at a time, in either process, through `.sync-lock`;
a second one reports `busy`. A server error (status 500 and above) or
429 does not refuse the copy: it ends the run as `failed`, the copy
still waiting.

The sync holds `.sync-lock` while it talks to the network, and iOS ends
a process that is suspended holding a lock file in a shared container.
So callers must run a sync under a background-time assertion
(`UIApplication.beginBackgroundTask` in the app,
`ProcessInfo.performExpiringActivity` in the extension) and cancel the
sync when the assertion expires; it ends with `interrupted` and
releases the lock.

Every change posts the Darwin notification `app.hrcek.pending.changed`,
which `PendingQueue.changes()` turns into an `AsyncStream`, so an open
app hears what the extension kept.
