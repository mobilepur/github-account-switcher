# Releasing

Pushing a version tag runs `.github/workflows/release.yml`. The workflow tests
the project, builds universal Apple Silicon and Intel binaries, signs them with
Developer ID, notarizes the package with Apple, and uploads the release archive
to GitHub.

## Required GitHub Actions secrets

- `BUILD_CERTIFICATE_BASE64`: Base64-encoded Developer ID Application `.p12`
  certificate.
- `P12_PASSWORD`: Password used when exporting the certificate.
- `DEVELOPER_ID_APPLICATION`: Complete Developer ID Application identity used
  by `codesign`.
- `APPLE_ID`: Apple ID used for notarization.
- `APPLE_TEAM_ID`: Apple Developer team ID.
- `APPLE_APP_SPECIFIC_PASSWORD`: App-specific password for `notarytool`.

The workflow stops before publishing if any signing secret is missing or if
Apple rejects notarization.

## Release steps

1. Update the version in `App/Info.plist` and the `gh-switcher version` output.
2. Move the relevant entries in `Docs/RELEASE_NOTES.md` from **Unreleased** to
   the new version.
3. Run `swift test` and `bash Tests/PackagingTests/ReleasePackageTests.sh`.
4. Create and push a matching tag such as `v0.1.3`.
5. Verify that the GitHub release contains `GitHub-Account-Switcher.tar.gz`.
