# Debugging

## Logs

Everything logs through `Log` in HrcekKit, with the subsystem
`app.hrcek` and a category per area: `app`, `api`, `auth`, `share`,
`ui`. App and share extension use the same subsystem.

Watch the simulator's log from a terminal:

```bash
xcrun simctl spawn booted log stream --level debug \
  --predicate 'subsystem == "app.hrcek"'
```

Narrow it with `AND category == "api"`. On a device, use Console.app
with the same subsystem filter, or `log stream` on the Mac while the
phone is connected.

Look back instead of streaming:

```bash
xcrun simctl spawn booted log show --last 10m --info \
  --predicate 'subsystem == "app.hrcek"'
```

## What is never logged

Tokens, passwords and email addresses never appear in a log in clear.
Values that could carry them are logged with `privacy: .private`.

## The debugger

Run the **Hrcek** scheme from Xcode as usual. To debug the share
extension, run the extension's scheme and choose Safari when Xcode asks
which app to run, then share a page to Hrček.

## Requests

Every request logs one line in the `api` category:

```
POST /api/auth/tokens/exchange → 201 in 0.084 seconds
```

A transport failure logs the `URLError` code instead, and a refusal
logs the server's error code. Debug builds also log request and
response bodies, after `LogRedaction` has replaced passwords, tokens,
identifiers and email addresses with `‹redacted›`. Release builds never
log bodies.

## The share extension

The extension logs under the same subsystem, category `share`:

```bash
xcrun simctl spawn booted log stream --level debug \
  --predicate 'subsystem == "app.hrcek" AND category IN {"share", "api"}'
```

To debug it in Xcode, run the extension's target and choose Safari
when Xcode asks which app to run. Then share a page to Hrček;
breakpoints in `HrcekShare/` and in HrcekKit's `ShareModel` and
`EntrySaver` are hit.

The extension and the app share nothing but the Keychain item. If the
extension says to sign in while the app shows you signed in, the two
are not using the same Keychain group: compare `HrcekKeychainGroup` in
both built Info.plists.
