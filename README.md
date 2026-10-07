# Hrček for iOS

Save the web page you are reading to your
[Hrček](https://github.com/Hrcek-app/hrcek) with your browser's Share
button.

**NOTE: Like Hrček itself, this is a usable experiment and a learning
project, without any guarantees.**

## Status

Early: the project, its checks and a first bilingual screen. Signing
in and saving the shared page come next.

## Documentation

- [User manual](docs/manual/en/index.md) ·
  [Priročnik (slovensko)](docs/manual/sl/index.md)
- [Developer documentation](docs/dev/index.md)
- [Working agreement](CLAUDE.md)

## Quick start

Requires Xcode 27 and [Homebrew](https://brew.sh).

```bash
brew bundle
uv tool install prek && prek install
open Hrcek.xcodeproj    # run the Hrcek scheme on an iPhone simulator
```

## Build your own copy

The simulator needs nothing more. To run on your own iPhone, copy
`Config/Local.xcconfig.example` to `Config/Local.xcconfig` and set a
bundle-identifier prefix you control and your Apple team ID. The file
is gitignored. See [development setup](docs/dev/development-setup.md).

## Licence

See [LICENSE](LICENSE).
