# Testing

Every change starts with a failing test. A change is done when all of
the following pass with no warnings, and it has been tried in the
simulator.

| Layer | Command | Where it runs |
|---|---|---|
| HrcekKit unit tests | `scripts/test-kit` | On the Mac, in seconds |
| HrcekKit in the simulator | `scripts/test-kit --simulator` | iPhone simulator; includes iOS-only tests |
| App tests: hosted unit tests and UI tests | `scripts/test-app` | iPhone simulator, in English and in Slovenian |
| End to end | `scripts/e2e` | A real Hrček backend, the app and Safari's share sheet in the simulator |

`HrcekTests` holds the few unit tests that need the app around them:
the Keychain tests. Package tests run in a bare test process with no
entitlements, where the Keychain refuses every call; hosted by the app,
they run with its real entitlements, so they also prove the shared
Keychain group works.

Unit tests use [Swift Testing](https://developer.apple.com/xcode/swift-testing/);
UI tests use XCUITest.

## Languages

`Hrcek.xctestplan` runs every UI test twice, in an English and a
Slovenian configuration. Each sets `HRCEK_TEST_LANGUAGE`, and
`launchApp()` starts the app in that language. Tests state what a
person should see with `TestLanguage.text(en:sl:)`, so a string left
untranslated fails the Slovenian run instead of slipping through.

`E2E.xctestplan` is for the end-to-end test, kept out of the default
plan.

## Warnings

`scripts/check-warnings` reads the build summary from each result
bundle and fails on any warning. Result bundles are kept under
`.build/results/`; open one in Xcode to see a failure in detail.

## Why `-collect-test-diagnostics never`

When a simulator test fails, xcodebuild by default runs
`simctl diagnose`, which takes about ten minutes and seldom helps. The
scripts turn it off.

## The stub server

UI tests sign in to a fake Hrček, `scripts/hrcek_stub.py`, which answers
only what the app calls, in English or Slovenian by `Accept-Language`.
`scripts/test-app` starts it on port 8765 (`HRCEK_STUB_PORT` to change)
and stops it afterwards. To run UI tests from Xcode, start it yourself
in a terminal first: `scripts/stub-server`.

| Email | Password | Answer |
|---|---|---|
| `nina@example.com` | `correct horse` | Signed in as "Nina", token `hrcek_stub` |
| `unconfirmed@example.com` | `correct horse` | `HRC-AUTH-0002`, address not confirmed |
| anything else | anything | `HRC-AUTH-0001`, wrong email or password |

`POST /stub/revoke` makes the stub refuse the token with
`HRC-AUTH-0004`, as if it had been removed on the website; the next
sign-in issues a working one again. It is the stub's only addition to
the real API.

A fake is only useful while it behaves like the real thing.
`scripts/contract-test` checks the behaviour the app relies on — the
status codes, error codes, translated messages and response fields —
against either:

```bash
scripts/contract-test --fake          # the stub; a commit hook runs this
scripts/contract-test --url http://127.0.0.1:8000 \
  --identifier you@example.com --password …   # a real Hrček
```

When the real server and the stub disagree, fix the stub.

## Things the UI tests have to handle

- After a successful sign-in, iOS offers to save the password.
  `declineSavingThePassword` taps Not Now, as a person would.
- A sheet that is still closing swallows taps without failing them;
  `tapWhenHittable` waits until the element can take the tap.
- A confirmation dialog exposes its button twice, nested, under one
  identifier; query it with `firstMatch`.

## End to end

`scripts/e2e` exercises the whole thing the way a person uses it:

1. It starts a real Hrček from `../hrcek` (or `$HRCEK_BACKEND_DIR`, or a
   fresh clone of `Hrcek-app/hrcek`) on port 8766 with a throwaway
   database, and creates a confirmed user with a random password.
2. It serves a small page, `scripts/e2e-page/`, on port 8767.
3. It runs the contract test against the real backend.
4. It runs `E2E.xctestplan`: `ShareE2ETests` signs in through the app,
   opens the page in Safari, shares it to Hrček and expects **Saved**,
   then shares it again and expects **Already saved**.
5. It asks the API for the entry and checks it was saved with the
   page's title.

The test reaches its credentials through `TEST_RUNNER_`-prefixed
environment variables, which xcodebuild hands to the test runner.

Safari's controls move between iOS versions. On iOS 27, Share lives in
the page menu (`MoreMenuButton`), the menu item is `ShareButton`, and
the extension's cell in the sheet is a cell labelled "Hrček". When a
query stops matching, the test attaches Safari's element tree and a
screenshot to the result bundle; export them with
`xcrun xcresulttool export attachments`.

The test plan runs in English. The share sheet uses the device's
language rather than the app's, so checking the extension in Slovenian
means switching the simulator's language
(`xcrun simctl spawn booted defaults write -g AppleLanguages -array sl`
and rebooting it).
