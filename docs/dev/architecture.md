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
