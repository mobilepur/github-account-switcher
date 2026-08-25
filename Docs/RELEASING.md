# Releasing

Pushing a version tag runs `.github/workflows/release.yml`. The workflow tests
the project, builds and ad-hoc signs universal Apple Silicon and Intel binaries,
publishes the archive and its checksum to GitHub, and updates the versioned Cask
in `mobilepur/homebrew-tap`.

The tag must match `App/Info.plist` and point to a commit already reachable from
`main`.

## Required GitHub Actions secret

- `HOMEBREW_TAP_GITHUB_TOKEN`: Fine-grained personal access token restricted to
  the `mobilepur/homebrew-tap` repository with only **Contents: Read and write**.

Use an expiration date and rotate the token when it expires. Do not reuse a
broad personal or GitHub CLI token. GitHub supplies the separate `GITHUB_TOKEN`
used to publish the release in this repository.

## Distribution security

The generated Cask pins a version-specific GitHub Release URL and the archive's
SHA256. Like `xlocal`, the binaries are not Developer ID-signed or notarized;
the Cask removes the quarantine attribute after Homebrew verifies the pinned
archive checksum.

## Release steps

1. Update the version in `App/Info.plist` and the `gh-switcher version` output.
2. Move the relevant entries in `Docs/RELEASE_NOTES.md` from **Unreleased** to
   the new version.
3. Run `swift test` and `bash Tests/PackagingTests/ReleasePackageTests.sh`.
4. Merge the release commit into `main`.
5. Create and push a matching tag such as `v0.1.4` from that `main` commit.
6. Verify that the GitHub release contains `GitHub-Account-Switcher.tar.gz` and
   `checksums.txt`.
7. Verify that `mobilepur/homebrew-tap` contains a Cask with the same version
   and archive checksum.
8. Run `brew upgrade --cask github-account-switcher` or perform a fresh Cask
   installation.

Release assets are immutable after publication. Re-running the workflow for the
same tag downloads and verifies the existing archive and checksum, then repairs
only the Homebrew Cask. Changed artifacts require a new version and tag.
