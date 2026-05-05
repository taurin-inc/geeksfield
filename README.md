# geeksfield

geeksfield is a native macOS workspace for generating, reviewing, iterating on, and exporting images with a local Codex login.

The app is built with SwiftUI, uses a local-first project store, and is distributed outside the Mac App Store with Developer ID signing, notarization, and Sparkle updates.

## Features

- Native macOS interface built for image generation workflows.
- Local Codex authentication via the existing `codex login` session.
- Project-based storage for generated images, metadata, references, and chat history.
- Image iteration tools, including inpainting and export workflows.
- Direct distribution with signed releases, notarized downloads, and automatic updates.

## Requirements

- macOS 26 or later.
- Xcode 26 or later.
- Swift 6.
- XcodeGen for local project generation.
- A local Codex login for provider-backed generation features.

## Download

Download the latest `geeksfield-vX.Y.Z.dmg` from [GitHub Releases](https://github.com/rapid-studio/geeksfield/releases) and drag `geeksfield.app` into Applications.

The `.dmg` is intended for first-time installs. Sparkle uses the release `.zip` asset for automatic updates after the app is installed.

## Development

This repository does not commit the generated Xcode project. Generate it from `project.yml`:

```bash
brew install xcodegen
xcodegen generate
open Geeksfield.xcodeproj
```

Then sign in to Codex locally if you want to exercise provider-backed generation:

```bash
codex login
```

## Release Process

Maintainer release steps are documented in [RELEASING.md](RELEASING.md).

The automatic update architecture is documented in [docs/updater.md](docs/updater.md).

## Project Status

geeksfield is under active development. Public releases may change quickly while the app's generation, editing, and update workflows settle.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

## Security

Please report security issues according to [SECURITY.md](SECURITY.md).

## License

MIT. See [LICENSE](LICENSE).
