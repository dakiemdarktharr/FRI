#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
mode=${1:-doctor}
if [[ "$mode" == --help ]]; then echo 'Usage: rebuild-on-mac.sh doctor|generate|build|local-app|unit-test|mac-test|ios-test [simulator-UDID]'; exit 0; fi
[[ "$(uname -s)" == Darwin ]] || { echo 'Xcode steps require macOS. Run rebuild-handoff.cjs check on other hosts.' >&2; exit 1; }
cd "$root"
out="$root/apple/artifacts/rebuild-082-$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$out"
run() { local label=$1; shift; "$@" 2>&1 | tee "$out/$label.log"; }
printf '%s\n' "Evidence: $out"
git rev-parse HEAD > "$out/commit.txt"
git status --short > "$out/worktree.txt"
case "$mode" in
 doctor)
  for tool in node python3 xcodebuild xcrun swift xcodegen; do command -v "$tool" >/dev/null || { echo "Missing: $tool" >&2; exit 1; }; done
  run handoff node apple/Tools/rebuild-handoff.cjs check
  run host sw_vers
  run architecture uname -m
  run xcode xcodebuild -version
  run sdks xcodebuild -showsdks
  run schemes xcodebuild -list -project apple/FRI.xcodeproj
  run simulators xcrun simctl list devices available
  ;;
 generate) run xcodegen xcodegen generate --spec apple/project.yml ;;
 build)
  run mac xcodebuild build -project apple/FRI.xcodeproj -scheme FRIMac -configuration Release -destination 'generic/platform=macOS' -derivedDataPath "$out/mac" ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO
  run mac-widgetkit xcodebuild build -project apple/FRI.xcodeproj -scheme FRIMacWidgetKit -configuration Release -destination 'generic/platform=macOS' -derivedDataPath "$out/mac-widgetkit" ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO
  run ios-simulator xcodebuild build -project apple/FRI.xcodeproj -scheme FRIiOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath "$out/ios" CODE_SIGNING_ALLOWED=NO
  echo 'Compilation only. These unsigned bundles are not distribution artifacts.'
  ;;
 local-app)
  run local-app xcodebuild build -project apple/FRI.xcodeproj -scheme FRIMac -configuration Release -destination 'generic/platform=macOS' -derivedDataPath "$out/local-app" ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= FRI_MAC_STORAGE_MODE=standalone FRI_MAC_ENTITLEMENTS=Config/MacStandalone.entitlements
  app="$out/local-app/Build/Products/Release/FRIMac.app"
  run local-signature codesign --verify --deep --strict "$app"
  echo "Local ad-hoc app: $app. No Developer ID, notarization or signed WidgetKit certification."
  ;;
 unit-test) run swift swift test --package-path apple/Packages/FRICore ;;
 mac-test)
  run mac-tests xcodebuild test -project apple/FRI.xcodeproj -scheme FRIMac -configuration Debug -destination 'platform=macOS' -parallel-testing-enabled NO -derivedDataPath "$out/mac-tests" -resultBundlePath "$out/mac-tests.xcresult"
  ;;
 ios-test)
  udid=${2:?Supply an installed iOS Simulator UDID, not a physical device}
  xcrun simctl list devices available -j > "$out/simulators.json"
  python3 - "$out/simulators.json" "$udid" <<'PY'
import json,sys
devices=json.load(open(sys.argv[1]))['devices']
assert any(d['udid']==sys.argv[2] and d.get('isAvailable') for runtime,items in devices.items() if 'iOS' in runtime for d in items), 'UDID is not an available iOS Simulator'
PY
  run ios-tests xcodebuild test -project apple/FRI.xcodeproj -scheme FRIiOS -configuration Debug -destination "platform=iOS Simulator,id=$udid" -parallel-testing-enabled NO -derivedDataPath "$out/ios-tests" -resultBundlePath "$out/ios-tests.xcresult" CODE_SIGNING_ALLOWED=NO
  ;;
 *) echo "Unknown mode: $mode" >&2; exit 2 ;;
esac
