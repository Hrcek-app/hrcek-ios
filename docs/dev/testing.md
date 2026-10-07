# Testing

Every change starts with a failing test. A change is done when all of
the following pass with no warnings, and it has been tried in the
simulator.

| Layer | Command | Where it runs |
|---|---|---|
| HrcekKit unit tests | `scripts/test-kit` | On the Mac, in seconds |
| HrcekKit in the simulator | `scripts/test-kit --simulator` | iPhone simulator; includes iOS-only tests |
| App UI tests | `scripts/test-app` | iPhone simulator, in English and in Slovenian |

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
