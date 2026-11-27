#!/bin/bash
set -euo pipefail
if [[ ${1:-} == --help ]]; then echo 'Usage: package-native-mac.sh /path/to/exported.app [--development] (no publishing or notarization)'; exit 0; fi
[[ "$(uname -s)" == Darwin ]] || { echo 'DMG creation requires macOS.' >&2; exit 1; }
root=$(cd "$(dirname "$0")/../.." && pwd)
app=${1:?Provide an exported app bundle}; [[ -d "$app" && "$app" == *.app ]] || exit 2
mode=${2:-distribution}
[[ "$mode" == distribution || "$mode" == --development ]] || { echo 'Unknown packaging mode' >&2; exit 2; }
app=$(cd "$app" && pwd)
plist="$app/Contents/Info.plist"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")
build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")
executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist")
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$build" =~ ^[0-9]+$ ]] || { echo 'Unexpected version/build format' >&2; exit 1; }
codesign --verify --deep --strict --verbose=2 "$app"
mkdir -p "$root/apple/artifacts"
out=$(mktemp -d "$root/apple/artifacts/package-082.XXXXXXXX")
codesign -dv --verbose=4 "$app" 2> "$out/signature.txt"
suffix=''
if [[ "$mode" == distribution ]]; then
 grep -q '^Authority=Developer ID Application:' "$out/signature.txt" || { echo 'Export with Developer ID, or explicitly choose --development for a local test DMG.' >&2; exit 1; }
else
 suffix='-development'
 printf '%s\n' 'Local testing only. This is not a Developer ID/notarization certification.' > "$out/DEVELOPMENT-ONLY.txt"
fi
lipo -info "$app/Contents/MacOS/$executable" | tee "$out/architectures.txt"
mkdir "$out/stage"
ditto "$app" "$out/stage/FRI.app"
ln -s /Applications "$out/stage/Applications"
image="$out/FRI-$version-build$build-mac$suffix.dmg"
hdiutil create -srcfolder "$out/stage" -volname "FRI $version$suffix" -format UDZO -fs HFS+ "$image"
hdiutil verify "$image"
shasum -a 256 "$image" > "$out/SHA256SUMS-before-notarization.txt"
echo "Created $out. This DMG is not yet notarized; follow the runbook. No latest link or installed app was changed."
