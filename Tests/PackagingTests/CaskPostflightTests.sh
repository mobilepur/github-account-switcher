#!/bin/bash

set -euo pipefail

repository_root="$(cd "$(dirname "$0")/../.." && pwd)"
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/github-account-switcher-cask-postflight.XXXXXX")"
trap 'rm -rf "$temporary_root"' EXIT

generated_cask="$temporary_root/github-account-switcher.rb"
checksum="$(printf '%064d' 0)"

bash "$repository_root/Scripts/render-homebrew-cask.sh" 0.1.4 "$checksum" > "$generated_cask"
ruby "$repository_root/Tests/PackagingTests/CaskPostflightTests.rb" "$generated_cask" "$temporary_root"
