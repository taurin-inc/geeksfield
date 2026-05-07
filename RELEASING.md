# Releasing

This project publishes direct-distribution macOS releases through GitHub Actions. Releases are Developer ID signed, notarized, attached to GitHub Releases, and advertised to installed apps through a Sparkle appcast hosted on GitHub Pages.

## Branches

- `dev` is the integration branch for regular development.
- Feature and fix branches should open pull requests into `dev`.
- `main` is the release branch.
- Only `dev` may be merged into `main`.
- Merge `dev` into `main` only when a public release should be produced.
- The release workflow runs on pushes to `main`.
- Feature and fix branches merged into `dev` are deleted automatically by the dev branch cleanup workflow.
- The repository-level automatic head branch deletion setting must stay disabled so `dev` is not deleted after `dev` -> `main` release PRs.

## Versioning

Before merging to `main`, update these values in `project.yml`:

- `MARKETING_VERSION`: the public app version, for example `0.1.3`.
- `CURRENT_PROJECT_VERSION`: the build number. Increase this for every release candidate that should be visible to Sparkle.

The workflow derives the GitHub tag from `MARKETING_VERSION`, for example `v0.1.3`. If the tag already exists, the workflow exits without publishing a duplicate release.

## Release Assets

Each successful release publishes two assets:

- `geeksfield-vX.Y.Z.dmg`: first-time install image for users.
- `geeksfield-vX.Y.Z.zip`: Sparkle update archive for installed apps.

The appcast points to the zip asset. The release page should direct users to the dmg.

## Release Notes

GitHub Release notes are generated automatically by the release workflow.
For standard `dev` -> `main` release pull requests, the workflow finds the merged pull request,
reads its commits and changed files, and writes Korean release notes before creating the release.

If the protected `release` environment has an `OPENAI_API_KEY` secret, the workflow uses it to
summarize the changes in natural Korean. Without that secret, the workflow still publishes the
release with conservative Korean fallback notes based on the changed paths.

## Required Secrets

The release environment requires these secrets:

- `APPLE_CERTIFICATE_BASE64`: base64-encoded Developer ID Application `.p12`.
- `APPLE_CERTIFICATE_PASSWORD`: password for the `.p12`.
- `APPLE_TEAM_ID`: Apple Developer Team ID.
- `APP_STORE_CONNECT_KEY_ID`: App Store Connect API key ID.
- `APP_STORE_CONNECT_ISSUER_ID`: App Store Connect issuer ID.
- `APP_STORE_CONNECT_API_KEY_BASE64`: base64-encoded App Store Connect API private key `.p8`.
- `SPARKLE_PRIVATE_KEY`: Sparkle EdDSA private key for signing update archives.

Secrets should be stored in the protected `release` environment, not as broad repository secrets.

Optional:

- `OPENAI_API_KEY`: OpenAI API key used only for automatic Korean GitHub Release notes.

## Release Checklist

1. Merge tested changes into `dev`.
2. Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.
3. Open a pull request from `dev` to `main`.
4. Review and merge the pull request when ready to publish.
5. Approve the `release` environment deployment in GitHub Actions.
6. Confirm the workflow created the GitHub Release and attached both the dmg and zip.
7. Confirm GitHub Pages published `https://taurin-inc.github.io/geeksfield/appcast.xml`.
8. Install the dmg on a clean machine or test account when changing signing, notarization, packaging, or update behavior.

## Branch Protection

`main` is protected by a branch ruleset:

- Pull requests are required.
- One approving review is required.
- Stale approvals are dismissed when new commits are pushed.
- Review conversations must be resolved before merging.
- Merge commit is the allowed merge method for `dev` -> `main` release pull requests.
- Release merge commits are created on `main`; they are not automatically added back to `dev`.

Repository administrators may bypass the ruleset when necessary, but routine changes should still go through pull requests.

## GitHub Pages

GitHub Pages is configured for GitHub Actions. The release workflow generates `docs/appcast.xml` during the run and deploys the `docs` directory as the Pages artifact.
