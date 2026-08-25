#!/bin/bash

set -euo pipefail

repository_root="$(cd "$(dirname "$0")/../.." && pwd)"
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/github-account-switcher-package-test.XXXXXX")"
trap 'rm -rf "$temporary_root"' EXIT

output_directory="$temporary_root/output"
archive="$output_directory/GitHub-Account-Switcher.tar.gz"
extracted_directory="$temporary_root/extracted"

bash "$repository_root/Scripts/build-release.sh" "$output_directory"

test -f "$archive"
mkdir -p "$extracted_directory"
tar -xzf "$archive" -C "$extracted_directory"

app="$extracted_directory/GitHub Account Switcher.app"
test -x "$app/Contents/MacOS/gh-switcher-menubar"
test -f "$app/Contents/Resources/AppIcon.icns"
plutil -lint "$app/Contents/Info.plist"
codesign --verify --deep --strict "$app"
app_signature="$(codesign --display --verbose=4 "$app" 2>&1)"
[[ "$app_signature" = *"runtime"* ]]
lipo "$app/Contents/MacOS/gh-switcher-menubar" -verify_arch arm64 x86_64

test -x "$extracted_directory/gh-switcher"
codesign --verify --strict "$extracted_directory/gh-switcher"
cli_signature="$(codesign --display --verbose=4 "$extracted_directory/gh-switcher" 2>&1)"
[[ "$cli_signature" = *"runtime"* ]]
lipo "$extracted_directory/gh-switcher" -verify_arch arm64 x86_64
app_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
test "$("$extracted_directory/gh-switcher" version)" = "gh-switcher $app_version"

checksum="$(shasum -a 256 "$archive" | awk '{print $1}')"
generated_cask="$temporary_root/github-account-switcher.rb"
bash "$repository_root/Scripts/render-homebrew-cask.sh" "$app_version" "$checksum" > "$generated_cask"

ruby -c "$generated_cask"
brew style "$generated_cask"
grep -Fq "version \"$app_version\"" "$generated_cask"
grep -Fq "sha256 \"$checksum\"" "$generated_cask"
grep -Fq 'url "https://github.com/mobilepur/github-account-switcher/releases/download/v#{version}/GitHub-Account-Switcher.tar.gz"' "$generated_cask"
grep -Fq 'system_command "/usr/bin/xattr"' "$generated_cask"
! grep -Fq 'version :latest' "$generated_cask"
! grep -Fq 'sha256 :no_check' "$generated_cask"

if bash "$repository_root/Scripts/render-homebrew-cask.sh" "v$app_version" "$checksum" >/dev/null 2>&1; then
    echo "Cask renderer accepted an invalid version" >&2
    exit 1
fi
if bash "$repository_root/Scripts/render-homebrew-cask.sh" "$app_version" invalid >/dev/null 2>&1; then
    echo "Cask renderer accepted an invalid checksum" >&2
    exit 1
fi

bash "$repository_root/Tests/PackagingTests/CaskPostflightTests.sh"
