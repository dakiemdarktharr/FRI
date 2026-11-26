#!/bin/bash
# Run on macOS after placing a native Release ZIP in artifacts/macos.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
artifacts=artifacts/macos
archive=$(python3 - "$artifacts" <<'PY'
from pathlib import Path
import re
import sys

archives = []
for item in Path(sys.argv[1]).glob("FRI-*-mac-arm64.zip"):
    match = re.fullmatch(r"FRI-(\d+)\.(\d+)\.(\d+)-build(\d+)-mac-arm64\.zip", item.name)
    if match:
        archives.append((tuple(map(int, match.groups())), item))
if not archives:
    sys.exit("No native Apple silicon build ZIP found")
print(max(archives)[1])
PY
)
image=${archive%.zip}.dmg
latest="$artifacts/latest/FRI-mac-arm64.dmg"
work=$(mktemp -d "$artifacts/.installer.XXXXXXXX")
mounted=false
cleanup() {
    if [[ "$mounted" == true ]]; then hdiutil detach "$work/mount" >/dev/null || return 1; fi
    rm -rf "$work"
}
trap cleanup EXIT
mkdir "$work/source" "$work/mount"
ditto -x -k "$archive" "$work/source"
app="$work/source/FRI.app"
plist="$app/Contents/Info.plist"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")
build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")
if [[ "$archive" != "$artifacts/FRI-$version-build$build-mac-arm64.zip" ]]; then
    echo "Archive filename disagrees with Info.plist ($version build $build): $archive" >&2
    exit 1
fi
if [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")" != com.fri.calendar.native.mac ]]; then
    echo "Expected the native FRI Mac app in $archive" >&2
    exit 1
fi
executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist")
lipo -verify_arch arm64 "$app/Contents/MacOS/$executable"
codesign --verify --deep --strict "$app"
ln -s /Applications "$work/source/Applications"

matches_archive() {
    hdiutil verify "$1" >/dev/null || return 1
    hdiutil attach -readonly -nobrowse -mountpoint "$work/mount" "$1" >/dev/null || return 1
    mounted=true
    local result=0
    if [[ "$(readlink "$work/mount/Applications")" != /Applications ]] ||
        ! codesign --verify --deep --strict "$work/mount/FRI.app" ||
        ! diff -qr "$app" "$work/mount/FRI.app"; then
        result=1
    fi
    hdiutil detach "$work/mount" >/dev/null || exit 1
    mounted=false
    return "$result"
}

if [[ ! -f "$image" ]] || ! matches_archive "$image"; then
    hdiutil create -srcfolder "$work/source" -volname "FRI $version build $build" \
        -format UDZO -fs HFS+ "$work/new.dmg"
    matches_archive "$work/new.dmg"
    mv -f "$work/new.dmg" "$image"
fi
mkdir -p "$(dirname "$latest")"
if ! cmp -s "$image" "$latest"; then
    cp "$image" "$work/latest.dmg"
    mv -f "$work/latest.dmg" "$latest"
fi
echo "Apple silicon installer: $version ($build)"
shasum -a 256 "$image" "$latest"
