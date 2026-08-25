#!/bin/bash

set -euo pipefail

repository_root="$(cd "$(dirname "$0")/.." && pwd)"
output_directory="${1:-$repository_root/dist}"
archive="$output_directory/GitHub-Account-Switcher.tar.gz"
temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/github-account-switcher-release.XXXXXX")"
trap 'rm -rf "$temporary_directory"' EXIT
staging_directory="$temporary_directory/package"
arm64_scratch="$temporary_directory/build-arm64"
x86_64_scratch="$temporary_directory/build-x86_64"
signing_identity="${CODESIGN_IDENTITY:--}"

if [[ -e "$archive" ]]; then
    echo "Release archive already exists: $archive" >&2
    exit 1
fi

swift build \
    --package-path "$repository_root" \
    --disable-sandbox \
    --scratch-path "$arm64_scratch" \
    --triple arm64-apple-macosx14.0 \
    -c release
swift build \
    --package-path "$repository_root" \
    --disable-sandbox \
    --scratch-path "$x86_64_scratch" \
    --triple x86_64-apple-macosx14.0 \
    -c release

app="$staging_directory/GitHub Account Switcher.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$output_directory"
lipo -create \
    "$arm64_scratch/arm64-apple-macosx/release/gh-switcher-menubar" \
    "$x86_64_scratch/x86_64-apple-macosx/release/gh-switcher-menubar" \
    -output "$app/Contents/MacOS/gh-switcher-menubar"
install -m 644 "$repository_root/App/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
install -m 644 "$repository_root/App/Info.plist" "$app/Contents/Info.plist"
lipo -create \
    "$arm64_scratch/arm64-apple-macosx/release/gh-switcher" \
    "$x86_64_scratch/x86_64-apple-macosx/release/gh-switcher" \
    -output "$staging_directory/gh-switcher"
chmod 755 "$app/Contents/MacOS/gh-switcher-menubar" "$staging_directory/gh-switcher"

if [[ "$signing_identity" = "-" ]]; then
    codesign --force --options runtime --sign - --identifier com.mobilepur.github-account-switcher.cli "$staging_directory/gh-switcher"
    codesign --force --options runtime --sign - "$app"
else
    : "${APPLE_ID:?APPLE_ID is required for notarized release builds}"
    : "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required for notarized release builds}"
    : "${APPLE_APP_SPECIFIC_PASSWORD:?APPLE_APP_SPECIFIC_PASSWORD is required for notarized release builds}"

    codesign --force --options runtime --timestamp --sign "$signing_identity" --identifier com.mobilepur.github-account-switcher.cli "$staging_directory/gh-switcher"
    codesign --force --options runtime --timestamp --sign "$signing_identity" "$app"

    notarization_archive="$temporary_directory/GitHub-Account-Switcher-notarization.zip"
    ditto -c -k --sequesterRsrc "$staging_directory" "$notarization_archive"
    xcrun notarytool submit "$notarization_archive" \
        --apple-id "$APPLE_ID" \
        --team-id "$APPLE_TEAM_ID" \
        --password "$APPLE_APP_SPECIFIC_PASSWORD" \
        --wait
    xcrun stapler staple "$app"
    xcrun stapler validate "$app"
    spctl --assess --type execute --verbose=2 "$app"
    spctl --assess --type execute --verbose=2 "$staging_directory/gh-switcher"
fi

codesign --verify --strict "$staging_directory/gh-switcher"
codesign --verify --deep --strict "$app"
tar -czf "$archive" -C "$staging_directory" "GitHub Account Switcher.app" gh-switcher

echo "$archive"
