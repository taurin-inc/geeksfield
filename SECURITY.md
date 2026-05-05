# Security Policy

## Reporting a Vulnerability

Please do not open public issues for vulnerabilities.

Report security issues privately to the maintainers through GitHub's private vulnerability reporting flow when available. If private reporting is not available, contact the repository owner directly.

Include:

- A clear description of the issue.
- Steps to reproduce.
- Impact and affected versions, if known.
- Any relevant logs, screenshots, or proof of concept details.

## Secrets and Signing Material

Developer ID certificates, App Store Connect API keys, and Sparkle private keys must never be committed to the repository.

Release credentials belong in the protected `release` environment in GitHub Actions.
