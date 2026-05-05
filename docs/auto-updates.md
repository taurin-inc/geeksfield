# Auto Updates

geeksfield should use Sparkle 2 for direct macOS distribution outside the Mac App Store.

The app uses Sparkle 2 through the `AutoUpdater` abstraction and UI hooks for "Check for Updates".

## Required Pieces

- Sparkle 2 package dependency.
- `SUFeedURL` in the app Info.plist.
- `SUPublicEDKey` in the app Info.plist.
- `SUEnableInstallerLauncherService` in the app Info.plist because geeksfield is sandboxed.
- Sparkle mach lookup temporary exceptions in the app entitlements because geeksfield is sandboxed.
- A Sparkle update asset URL that points directly to the downloadable zip.
- A signed appcast XML feed that includes the version, build number, asset length, and Sparkle EdDSA signature.

Sparkle's documentation recommends HTTPS appcast hosting, Developer ID code signing, Apple notarization, and EdDSA signing for update archives.

## Recommended Hosting

GitHub Pages is configured to publish from GitHub Actions.

The appcast URL is:

```text
https://rapid-studio.github.io/geeksfield/appcast.xml
```

The source file is `docs/appcast.xml`.

## Release Flow

1. The `main` branch release workflow builds and notarizes `geeksfield.app`.
2. The workflow packages the stapled app as `geeksfield-vX.Y.Z.zip` for Sparkle updates.
3. The workflow creates and notarizes `geeksfield-vX.Y.Z.dmg` for first-time installs.
4. The workflow signs the zip with Sparkle's private EdDSA key.
5. The workflow creates the GitHub Release and uploads both the dmg and zip.
6. The workflow updates `appcast.xml` with the zip asset and deploys it to GitHub Pages.
7. Installed apps check `SUFeedURL`, verify the EdDSA signature using `SUPublicEDKey`, and offer the update.

## Secrets

In addition to the Apple signing and notarization secrets in `docs/release.md`, updater publishing needs:

- `SPARKLE_PRIVATE_KEY`: Sparkle EdDSA private key for signing update archives.

The public key from the same key pair must be baked into the app as `SUPublicEDKey`.

The current Sparkle key account used locally is `rapid-studio.geeksfield`. The public key baked into the app is:

```text
E4GFYrsJhIx3C8TRVuY9Mga0wcxUIjZ+N8URAqQilQk=
```

## Open Question

The team note mentions checking how OpenStudio handles automatic updates. The exact OpenStudio repository or product URL is needed before copying its approach. If it is also a direct-distributed macOS app, the expected pattern is Sparkle 2 with a GitHub Release asset and a maintained appcast feed.
