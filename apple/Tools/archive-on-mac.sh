#!/bin/bash
set -euo pipefail
if [[ ${1:-} == --help ]]; then echo 'Usage: archive-on-mac.sh mac|ios /absolute/path/to/filled-export-options.plist'; exit 0; fi
[[ "$(uname -s)" == Darwin ]] || { echo 'Archive/export requires macOS and real signing configuration.' >&2; exit 1; }
root=$(cd "$(dirname "$0")/../.." && pwd)
platform=${1:?Choose mac or ios}; options=${2:?Provide an export-options plist}
[[ -f "$options" ]] || { echo 'Export options file does not exist.' >&2; exit 1; }
options=$(cd "$(dirname "$options")" && pwd)/$(basename "$options")
python3 - "$options" "$platform" <<'PY'
import plistlib,sys
p=plistlib.load(open(sys.argv[1],'rb'))
assert p.get('teamID') and 'REPLACE' not in str(p) and 'YOUR_' not in str(p), 'Fill real signing values first'
assert p.get('destination','export')=='export', 'This script exports locally; uploading is a separate step'
assert p.get('method')=={'mac':'developer-id','ios':'app-store-connect'}[sys.argv[2]], 'Use Xcode-supported export method for this platform'
PY
case "$platform" in
 mac) scheme=${FRI_MAC_SCHEME:-FRIMac}; [[ "$scheme" == FRIMac || "$scheme" == FRIMacWidgetKit ]] || exit 2; destination='generic/platform=macOS' ;;
 ios) scheme=FRIiOS; destination='generic/platform=iOS' ;;
 *) echo 'Choose mac or ios' >&2; exit 2 ;;
esac
cd "$root"
out="$root/apple/artifacts/archive-$scheme-$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$out"
git rev-parse HEAD > "$out/commit.txt"
xcodebuild archive -project apple/FRI.xcodeproj -scheme "$scheme" -configuration Release -destination "$destination" -archivePath "$out/$scheme.xcarchive" 2>&1 | tee "$out/archive.log"
xcodebuild -exportArchive -archivePath "$out/$scheme.xcarchive" -exportOptionsPlist "$options" -exportPath "$out/export" 2>&1 | tee "$out/export.log"
echo "Exported locally: $out/export. Run signature, runtime and distribution checks before publishing."
