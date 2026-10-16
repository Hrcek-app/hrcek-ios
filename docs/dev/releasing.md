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

Signing an archive normally needs a development certificate in the
keychain, which a fresh CI runner has not got. So the script builds
the archive unsigned, signs each bundle locally with its entitlements
(a signature that needs no certificate) and lets the export sign it
for distribution. The export keeps those entitlements: the app group
and Keychain group that app and share extension share. A new
`$(…)` setting in `Support/*.entitlements` must be filled in by the
script too; it stops if one is not.

The app declares it uses only exempt encryption (HTTPS), so App Store
Connect does not ask about export compliance for each build.

Processing takes a few minutes. Then the build is in the app's
TestFlight tab: members of your team can install it straight away;
testers outside it need a public link or an invitation, and Apple
reviews the first build they see.

## Every month, without anyone

`.github/workflows/testflight.yml` runs `scripts/testflight` on the
first of each month at 06:00 UTC, so testers always have a build well
inside its 90 days and get what was merged since. It can be started by
hand from the Actions tab too. It builds `main` as it is, without
running the tests again, so keep `main` green.

It signs with an App Store Connect API key instead of an Xcode login.
Set up once, in the repository's Settings → Secrets and variables →
Actions:

| Kind | Name | Value |
|---|---|---|
| Variable | `HRCEK_BUNDLE_PREFIX` | As in `Local.xcconfig` |
| Variable | `HRCEK_DEVELOPMENT_TEAM` | As in `Local.xcconfig` |
| Secret | `HRCEK_ASC_KEY_ID` | The key's ID |
| Secret | `HRCEK_ASC_ISSUER_ID` | The issuer ID above the list of keys |
| Secret | `HRCEK_ASC_KEY` | The whole `.p8` file |

Make the key in App Store Connect → Users and Access → Integrations →
App Store Connect API, as a team key with the Admin role: only Admin
may use the cloud-managed distribution certificate. Apple lets you
download the `.p8` once. API keys do not expire, and the cloud
certificate is renewed by Apple, so nothing here needs a yearly
turn.

Without `HRCEK_DEVELOPMENT_TEAM` the job is skipped, so forks are not
bothered by it.

GitHub silently disables scheduled workflows in a public repository
after 60 days with no activity. The last step enables the workflow
again on every run, which restarts that count. When a scheduled run
fails, GitHub emails whoever last changed its schedule.
