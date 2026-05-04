# Release Process

## Branches

- `dev` is the working branch. Feature and fix branches should open pull requests into `dev`.
- `main` is the release branch. Only merge `dev` into `main` when a release should be produced.
- Release automation runs on pushes to `main`, but it only publishes when `MARKETING_VERSION` in `project.yml` maps to a tag that does not already exist.

## Versioning

Before merging to `main`, update these values in `project.yml`:

- `MARKETING_VERSION`: user-facing app version, for example `0.1.0`.
- `CURRENT_PROJECT_VERSION`: build number. Increase this for each release build.

The GitHub release tag is derived from `MARKETING_VERSION`, for example `v0.1.0`.

## GitHub Secrets

The release workflow needs these repository secrets:

- `APPLE_CERTIFICATE_BASE64`: base64-encoded Developer ID Application `.p12` certificate.
- `APPLE_CERTIFICATE_PASSWORD`: password for the `.p12` certificate.
- `APPLE_TEAM_ID`: Apple Developer Team ID.
- `APP_STORE_CONNECT_KEY_ID`: App Store Connect API key ID.
- `APP_STORE_CONNECT_ISSUER_ID`: App Store Connect issuer ID.
- `APP_STORE_CONNECT_API_KEY_BASE64`: base64-encoded App Store Connect API private key `.p8`.
- `SPARKLE_PRIVATE_KEY`: Sparkle EdDSA private key for signing update archives.

Create the base64 values locally:

```bash
base64 -i DeveloperIDApplication.p12 | pbcopy
base64 -i AuthKey_KEYID.p8 | pbcopy
```

Export the Sparkle private key from the local Keychain when registering `SPARKLE_PRIVATE_KEY`:

```bash
/tmp/geeksfield-sparkle-derived/Build/Products/Release/generate_keys --account rapid-studio.geeksfield -x /tmp/geeksfield-sparkle-private-key
```

## Release

1. Merge tested changes into `dev`.
2. Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.
3. Open a pull request from `dev` to `main`.
4. Merge when ready to publish.
5. Confirm the `Release macOS App` workflow created the GitHub Release and attached `Geeksfield-vX.Y.Z.zip`.
6. Confirm GitHub Pages published the updated appcast at `https://rapid-studio.github.io/geeksfield/appcast.xml`.

If the version tag already exists, the workflow exits without publishing a duplicate release.

## Branch Protection

Protect `main` with these rules when the GitHub plan supports it:

- Require pull request before merging.
- Require at least one approving review.
- Dismiss stale approvals when new commits are pushed.
- Require conversation resolution before merging.
- Restrict direct pushes to maintainers or disallow direct pushes entirely, while allowing the release workflow to update `docs/appcast.xml`.

GitHub Pages is configured from `main` branch `/docs`, so release changes that update `docs/appcast.xml` are published at `https://rapid-studio.github.io/geeksfield/appcast.xml`.
