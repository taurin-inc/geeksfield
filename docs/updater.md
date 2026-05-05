# Update Distribution

geeksfield uses Sparkle 2 for automatic updates outside the Mac App Store.

## Overview

- Installed apps read the appcast from `https://rapid-studio.github.io/geeksfield/appcast.xml`.
- The appcast advertises the latest Sparkle update zip.
- Sparkle verifies the zip with the EdDSA public key embedded in the app.
- GitHub Releases host both user-facing dmg installers and Sparkle zip archives.
- GitHub Pages hosts the generated appcast.

## App Configuration

The app includes the required Sparkle configuration in `Info.plist`:

- `SUFeedURL`
- `SUPublicEDKey`
- `SUEnableInstallerLauncherService`
- `SUEnableAutomaticChecks`
- `SUScheduledCheckInterval`

Because the app is sandboxed, the entitlements include the temporary mach lookup exceptions required by Sparkle's installer services.

## Release Flow

1. The release workflow builds `geeksfield.app`.
2. The app is signed with Developer ID Application.
3. The app is notarized and stapled.
4. The workflow creates `geeksfield-vX.Y.Z.zip` for Sparkle updates.
5. The workflow creates and notarizes `geeksfield-vX.Y.Z.dmg` for first-time installs.
6. The zip is signed with the Sparkle EdDSA private key.
7. The GitHub Release is created with both assets.
8. The appcast is updated with the zip URL, file length, build number, version, and EdDSA signature.
9. The appcast is deployed to GitHub Pages.

## Asset Roles

The dmg and zip serve different audiences:

- The dmg is the public download for new users. It presents `geeksfield.app` next to an Applications shortcut.
- The zip is for Sparkle. It lets installed apps replace the application bundle during an update.

Do not point the appcast at the dmg unless the update strategy is intentionally changed.

## Keys

Sparkle update signatures use an EdDSA key pair. The private key is stored as the `SPARKLE_PRIVATE_KEY` secret in the protected `release` environment. The public key is embedded in the app as `SUPublicEDKey`.

Current public key:

```text
E4GFYrsJhIx3C8TRVuY9Mga0wcxUIjZ+N8URAqQilQk=
```
