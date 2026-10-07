# Hooks and CI

The same checks run before every commit and on every push, so CI is
never the first to find a problem.

## Commit hooks

[prek](https://github.com/j178/prek) runs `.pre-commit-config.yaml`:

| Hook | Why |
|---|---|
| whitespace, end of file, YAML and JSON, merge conflicts, large files | Keep the tree clean |
| shellcheck | Scripts are code too |
| gitleaks | No secret ever reaches the repository |
| swift-format | One layout, no arguments about it |
| SwiftLint | Lint and complexity: cyclomatic complexity, function, type and file length, nesting |
| translations | Catalogues match the source; a fixer that stops the commit |
| translation status | Lists Slovenian gaps; never fails |
| HrcekKit tests | Fast, so they run on every commit that touches the package |

The UI tests take minutes, so they run on CI and before a change is
called done, not on every commit.

Run everything yourself with `prek run --all-files`.

## CI

`.github/workflows/ci.yml` runs on every pull request and on `main`:

| Job | Runs |
|---|---|
| hooks | Every hook above on all files, then gitleaks over the whole history |
| kit | `scripts/test-kit` and `scripts/test-kit --simulator` |
| app | `scripts/test-app` |

Jobs run on GitHub's `xcode-27` macOS image, which is a preview at the
time of writing. Xcode is selected explicitly with `DEVELOPER_DIR`.
Every action is pinned to a commit SHA. CI needs no secrets. A failing
test job uploads its result bundles as an artifact.
