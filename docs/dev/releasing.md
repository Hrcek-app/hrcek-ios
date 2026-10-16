# Releasing to TestFlight

`scripts/testflight` archives a Release build, signs it for App Store
distribution and uploads it to App Store Connect. Run it from `main`
after the checks in [CLAUDE.md](../../CLAUDE.md) pass.

## Once per Apple account

1. Set up `Config/Local.xcconfig` as in
   [Development setup](development-setup.md). The bundle identifier is
   permanent once a build is uploaded, and the app group and Keychain
   group derive from it.
2. Sign in to your Apple account in Xcode → Settings → Accounts. The
   script uses that account; with `-allowProvisioningUpdates`, Xcode
   registers the identifiers and app group and makes the distribution
   certificate and profiles.
3. In [App Store Connect](https://appstoreconnect.apple.com), add a new
   iOS app with the bundle identifier `<prefix>.Hrcek`. Apple offers no
   way to do this from the command line.

## Each release

```bash
scripts/testflight
```

The build number is the UTC time of the build, such as `202610161302`,
so each upload is higher than the last without a counter in the
repository. Raise `MARKETING_VERSION` in `Config/Shared.xcconfig` when
the version people see should change.

The app declares it uses only exempt encryption (HTTPS), so App Store
Connect does not ask about export compliance for each build.

Processing takes a few minutes. Then the build is in the app's
TestFlight tab: members of your team can install it straight away;
testers outside it need a public link or an invitation, and Apple
reviews the first build they see.
