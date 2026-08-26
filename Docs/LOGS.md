# Commit Log

This file records every commit created by an agent. Add new entries at the top
using this format:

```markdown
## YYYY-MM-DD — Commit subject

- Summary: What changed and why.
- Verification: Tests and checks performed.
```

## 2026-08-26 — Fix avatar isolation and prepare 0.1.8

- Summary: Keep AppKit avatar images on the main actor so release builds remain
  compatible with Xcode 16.4, and bump the app and CLI to 0.1.8 for the
  immutable replacement release.
- Verification: Captured the original GitHub Actions compile failure, observed
  the focused 0.1.8 CLI version test fail before the version update, then passed
  30 Swift tests, the universal release packaging test, the release workflow
  contract, property-list validation, and `git diff --check`.

## 2026-08-26 — Prepare 0.1.7 release

- Summary: Bump the app and CLI to 0.1.7 and move the login-start avatar fix
  into the 0.1.7 release notes.
- Verification: Observed the focused CLI version test fail before the version
  update, then passed 30 Swift tests, the universal release packaging test,
  property-list validation, `git diff --check`, and an independent release
  review with no blocking findings.

## 2026-08-26 — Wait for connectivity when loading avatars

- Summary: Keep the menu bar avatar request pending while the app waits for
  network connectivity after login, and prevent stale or cancelled account
  requests from clearing or replacing the current avatar.
- Verification: Observed focused tests fail before the connectivity, stale-state,
  and cancellation changes; then passed 30 Swift tests, `git diff --check`, and
  an independent read-only change review with no remaining findings.

## 2026-08-25 — Restore README app icon

- Summary: Restore the centered GitHub Account Switcher app icon below the
  README title so the project branding is visible again.
- Verification: Confirmed the README image target resolves to the valid 1024 ×
  1024 PNG asset and `git diff --check` passed.

## 2026-08-25 — Refine About links and prepare 0.1.6

- Summary: Style the About version link in muted gray with a right chevron,
  remove the icon from problem reporting, and bump the app and CLI to 0.1.6.
- Verification: Confirmed the original blue external-link treatment and problem
  icon in the supplied screenshots, observed the 0.1.6 CLI version test fail
  before implementation, then passed 27 Swift tests, the universal release
  packaging test, property-list validation, a packaged-app visual check, and
  `git diff --check`.

## 2026-08-25 — Add About section and prepare 0.1.5

- Summary: Add an About section to the menu bar panel with the app name, a
  version-specific GitHub release-notes link, and GitHub problem reporting;
  bump the app and CLI to version 0.1.5 and add its release notes.
- Verification: Observed the release-link and CLI-version tests fail before
  implementation, then passed 27 Swift tests, the universal release packaging
  test, property-list validation, a packaged-app visual check, and
  `git diff --check`.

## 2026-08-25 — Use Swift 6 release runner

- Summary: Move the GitHub Actions release job from the macOS 14 image with
  Swift 5.10 to the macOS 15 image required by the package's Swift 6 tools
  version, and guard that runner contract with a packaging test.
- Verification: Reproduced the GitHub Actions Swift toolchain failure, observed
  the new workflow contract fail before and pass after the fix, and passed 26
  Swift tests, universal release packaging, Homebrew style, shell and YAML
  syntax, and `git diff --check`.

## 2026-08-25 — Harden Homebrew release retries

- Summary: Clear quarantine only when present on the installed app and staged
  CLI, and keep published tag assets immutable while allowing retries to repair
  the Homebrew Cask from the existing checksum.
- Verification: Cask postflight integration test, immutable-release workflow
  contract, 26 Swift tests, universal release packaging, Homebrew style, shell,
  Ruby, YAML, and property-list syntax, and `git diff --check` passed.

## 2026-08-25 — Match xlocal Homebrew release flow

- Summary: Replace Developer ID signing and notarization with the xlocal-style
  Homebrew flow: ad-hoc signed universal artifacts, pinned checksums, and an
  automatically generated Cask in `mobilepur/homebrew-tap`.
- Verification: 26 Swift tests, release packaging and Cask generation tests,
  release workflow contract checks, shell and Ruby syntax, Homebrew style,
  property-list validation, and `git diff --check` passed.

## 2026-08-25 — Prepare 0.1.4 release

- Summary: Bump the app, CLI, and Homebrew version contract to 0.1.4 and move
  the completed Cask, release automation, and README changes into the 0.1.4
  release notes.
- Verification: Focused CLI version test, full Swift test suite, release
  packaging test, property-list validation, version consistency check, and
  `git diff --check` passed.

## 2026-08-25 — Refine README tone and SSH key wording

- Summary: Make the README introduction and behavior description more neutral,
  and clarify that the app stores SSH key paths without reading or modifying
  the key files.
- Verification: 26 Swift tests and `git diff --check` passed.

## 2026-08-25 — Prepare Homebrew Cask distribution

- Summary: Add Cask release packaging, signing and notarization automation,
  refresh the README, and introduce maintained release and commit documentation.
- Verification: 26 Swift tests, release packaging test, Homebrew style, shell and
  workflow syntax, and `git diff --check` passed.
