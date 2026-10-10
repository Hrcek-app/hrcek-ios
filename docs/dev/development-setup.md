# Development setup

## What you need

- **Xcode 27.** The project uses file-system synchronized folders and
  Swift 6.4, and CI builds on GitHub's `xcode-27` image. Older Xcode
  versions will not open it.
- **Homebrew**, for the command-line tools.

```bash
brew bundle                    # swiftlint, gitleaks, uv
uv tool install prek
prek install                   # the commit hooks
```

`uv` runs the small Python helpers in `scripts/`. Each has a `.lock`
file beside it, so they run the same everywhere.

## Building and running

Open `Hrcek.xcodeproj` and run the **Hrcek** scheme on an iPhone
simulator. From the command line, `scripts/test-app` builds the app and
runs the UI tests; the app it built is under
`.build/xcode/Build/Products/Debug-iphonesimulator/`.

`scripts/simulator` picks the newest iPhone simulator installed. Set
`HRCEK_SIMULATOR` to a device name, such as `iPhone 17`, to choose one.

## Settings and your own copy

Build settings live in `Config/`, not in the project file:

| File | Holds |
|---|---|
| `Shared.xcconfig` | Everything common: versions, Swift settings, warnings as errors |
| `Hrcek.xcconfig`, `HrcekShare.xcconfig`, `HrcekUITests.xcconfig` | Per-target identifiers and Info.plist settings |
| `Local.xcconfig` | Yours alone, gitignored; included last |

The simulator needs no `Local.xcconfig`. To run on a device, copy
`Local.xcconfig.example` to `Local.xcconfig` and set:

- `HRCEK_BUNDLE_PREFIX` — a reverse-DNS prefix you control. The app is
  `<prefix>.Hrcek` and the share extension `<prefix>.Hrcek.Share`; an
  extension's identifier must extend its app's.
- `DEVELOPMENT_TEAM` — your Apple team ID, from Xcode → Settings →
  Accounts.

Nothing else in the repository names a team or a person, so a fork
needs no other change. The shared Keychain group that app and share
extension use is derived from the same two values:
`<team prefix>.<HRCEK_BUNDLE_PREFIX>.Hrcek.shared`.

## The project file

`Hrcek.xcodeproj` is committed. Because its folders are synchronized,
adding, renaming or removing a source file does not touch
`project.pbxproj`; only new targets or build phases do. Xcode 27.2
introduces a JSON project format; once it is out of beta, converting is
one setting in the file inspector.

Info.plists live in `Support/`, outside the synchronized folders: a
plist inside one would be copied into the app as a resource and collide
with the processed one.

## The app icon

`Hrcek/Assets.xcassets/AppIcon.appiconset/app-icon.png` is the only
size: Xcode derives the rest. It must be 1024 × 1024 and fully opaque.
iOS draws transparent pixels as black and applies its own rounded
mask, and App Store Connect rejects an icon with an alpha channel. So
replace it with full-bleed artwork, not a picture that is already
rounded. The share extension uses the app's icon.
