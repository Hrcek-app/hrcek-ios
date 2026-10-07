# Hrček for iOS — working agreement

The iOS client for Hrček (https://github.com/Hrcek-app/hrcek), a
family-scale service for saving references to web pages. Its main use
is the Share sheet: share a page from a browser, Hrček saves it. Prefer
the simple option.

## Stack

Xcode 27, Swift 6, SwiftUI, iOS 18+. Logic and view models live in
the local package `HrcekKit`; the app and the share extension are
thin. String Catalogs for English and Slovenian.

## Commands

| Purpose | Command |
|---|---|
| Install tools | `brew bundle && uv tool install prek && prek install` |
| Package tests (fast) | `scripts/test-kit` |
| Package tests in the simulator (Keychain too) | `scripts/test-kit --simulator` |
| App UI tests, English and Slovenian | `scripts/test-app` |
| Format / lint | `scripts/format` / `scripts/lint` |
| All hooks | `prek run --all-files` |
| Sync catalogues | `scripts/translations` |
| Translate a string | `scripts/translate CATALOG KEY VALUE` |
| Translation gaps | `scripts/translation-status` |

Python helpers run through `uv`; never call `python` directly.

## How we work

**Test-driven.** Write the failing test, watch it fail for the reason
you expect, then write the least code that passes.

**Warnings are errors.** Fix the cause. Never silence a warning. If it
cannot be fixed, stop and ask.

**See it run.** A change is not done until it has been used in the
simulator, the way a person would, and the screenshot looked at. For
the share extension that means sharing from Safari.

**Done means:** hooks pass, `scripts/test-kit`,
`scripts/test-kit --simulator` and `scripts/test-app` pass with no
warnings, docs are updated.

**Commits.** One logical change per commit, one PR per commit, stacked
with `gh stack` when dependent. Fixes are amended into the commit they
belong to. Messages are short and say why, never how. No
`Co-Authored-By` or other trailers.

**Comments** say why, not how, unless how is not obvious.

## Non-negotiable rules

- **Every user-facing string is translatable**, with English text as
  the key (`Text("Sign in")`, `String(localized: "…", bundle: L10n.bundle)`
  in HrcekKit), and translated to Slovenian in the same commit. Counts
  use plural variations; Slovenian has one, two, few and other.
- **No secrets in the repository.** Personal settings go in the
  gitignored `Config/Local.xcconfig`. gitleaks runs on every commit.
- **Never log a token, password or email address** in clear; use
  `privacy: .private`.
- **Branch on API error codes, never messages.**
- **Docs are part of the change**: `docs/dev/` for developers,
  `docs/manual/en` and `docs/manual/sl` for people using the app.
  Lines wrap at 80 characters.
- **Changes over 100 lines need a review guide** in `REVIEW_GUIDE.md`
  at the root (gitignored): read order and what deserves a close look.

## Layout

```
Hrcek/            app (SwiftUI views only)
HrcekShare/       share extension
HrcekUITests/     XCUITest, run in English and Slovenian
HrcekKit/         package: API client, auth, storage, view models
Config/           xcconfig; Local.xcconfig is yours and gitignored
Support/          Info.plists and entitlements
scripts/          everything the hooks and CI run
docs/dev/         developer documentation
docs/manual/      user manual, English and Slovenian
```

`docs/superpowers/` holds working specs and plans and is gitignored.
