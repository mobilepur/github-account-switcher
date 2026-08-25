#!/bin/bash

set -euo pipefail

repository_root="$(cd "$(dirname "$0")/../.." && pwd)"
workflow="$repository_root/.github/workflows/release.yml"
build_script="$repository_root/Scripts/build-release.sh"
readme="$repository_root/README.md"
release_guide="$repository_root/Docs/RELEASING.md"

grep -Fq 'git merge-base --is-ancestor "$GITHUB_SHA" origin/main' "$workflow"
grep -Fq 'persist-credentials: false' "$workflow"
grep -Fq 'Scripts/render-homebrew-cask.sh' "$workflow"
grep -Fq 'checksums.txt' "$workflow"
grep -Fq -- '--clobber' "$workflow"
grep -Fq 'mobilepur/homebrew-tap' "$workflow"
grep -Fq 'HOMEBREW_TAP_GITHUB_TOKEN' "$workflow"

publish_line="$(grep -nF 'name: Publish release package' "$workflow" | cut -d: -f1)"
tap_checkout_line="$(grep -nF 'repository: mobilepur/homebrew-tap' "$workflow" | cut -d: -f1)"
if [[ "$tap_checkout_line" -le "$publish_line" ]]; then
    echo "Homebrew tap credentials are exposed before the release build finishes" >&2
    exit 1
fi

if grep -Eq 'APPLE_|BUILD_CERTIFICATE|P12_PASSWORD|DEVELOPER_ID' "$workflow" "$build_script"; then
    echo "Release automation still requires Apple signing credentials" >&2
    exit 1
fi

grep -Fq 'brew install --cask mobilepur/tap/github-account-switcher' "$readme"
grep -Fq '`HOMEBREW_TAP_GITHUB_TOKEN`' "$release_guide"
if grep -Eq 'APPLE_|BUILD_CERTIFICATE|P12_PASSWORD|DEVELOPER_ID' "$release_guide"; then
    echo "Release guide still documents Apple signing credentials" >&2
    exit 1
fi

test ! -e "$repository_root/Casks/github-account-switcher.rb"
test ! -e "$repository_root/Formula/gh-switcher.rb"
