# Contributing

Thanks for taking the time to contribute to geeksfield.

## Development Flow

- Open feature and fix pull requests against `dev`.
- `main` is reserved for releases.
- Keep pull requests focused and small enough to review.
- Prefer changes that follow the existing SwiftUI and storage patterns.

## Local Setup

Generate the Xcode project before opening the app:

```bash
brew install xcodegen
xcodegen generate
open Geeksfield.xcodeproj
```

Some generation features require a local Codex login:

```bash
codex login
```

## Pull Requests

Before opening a pull request:

- Confirm the project regenerates with `xcodegen generate`.
- Build locally in Xcode when your change touches app code.
- Update documentation when changing release, signing, update, storage, or user-facing behavior.
- Avoid committing generated Xcode project files.

## Releases

Release work is maintainer-only. See [RELEASING.md](RELEASING.md) for the release process.
