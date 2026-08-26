# Release Notes

## Unreleased

## 0.1.9 — 2026-08-26

### Changed

- The menu bar icon now shows wider black horizontal switching arrows with
  full-length shafts, detached open arrowheads, and rounded tails behind a
  rounded black badge containing the active account avatar or white initials.

## 0.1.8 — 2026-08-26

### Fixed

- Release builds now compile on the macOS 15 GitHub Actions runner by keeping
  AppKit avatar images on the main actor.

## 0.1.7 — 2026-08-26

### Fixed

- The active account avatar now waits for network connectivity when the app
  starts automatically at login.

## 0.1.6 — 2026-08-25

### Changed

- The About section now uses a muted version link with a chevron and shows the
  problem-reporting link without an icon.

## 0.1.5 — 2026-08-25

### Added

- The menu bar panel now has an About section showing the app name and version,
  with links to the matching GitHub release notes and the GitHub issue form.

## 0.1.4 — 2026-08-25

### Changed

- GitHub Account Switcher can be installed as a Homebrew Cask so the app is
  available from Applications, Spotlight, and Launchpad.
- Release tags now publish an ad-hoc signed universal app bundle and CLI with a
  pinned checksum, then update the versioned Cask in `mobilepur/homebrew-tap`.
- Release automation now uses a Swift 6-capable macOS 15 runner.
- The README now explains menu bar account switching, installation, and how the
  app handles SSH keys and GitHub credentials.

## 0.1.3 — 2026-08-24

### Changed

- Refined the adaptive menu bar icon geometry.

## 0.1.2 — 2026-08-24

### Changed

- Restored the adaptive menu bar icon.

## 0.1.1 — 2026-08-24

### Changed

- Matched the menu bar icon to the app icon.

## 0.1.0 — 2026-08-24

### Added

- Initial GitHub account switching from the command line and macOS menu bar.
- Synchronized switching of GitHub CLI accounts and their local SSH identities.
- Account configuration, GitHub avatars, Start at Login, and problem reporting.
