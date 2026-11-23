# Xcode project and reproducible build

Use current stable Xcode supported by the Mac and required submission SDK. Check [system requirements](https://developer.apple.com/xcode/system-requirements/) and [upload requirements](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/); do not select a beta merely because it is first in the table. Capture xcodebuild -version, xcodebuild -showsdks, sw_vers and uname -m. Proposed deployment floors: iOS 17/macOS 14 for interactive widgets, glass available only on 26+ with fallback. These are proposed settings, not an existing compiled project.

## Create once

1. Clone and branch codex/apple-native; read parity/PDF and run existing JS domain tests.
2. Create macOS SwiftUI App FRIMac and iOS SwiftUI App FRIiOS in apple/FRI.xcodeproj. Display name FRI. Register bundle IDs under the actual team; keep com.fri.calendar on Mac only if the team can provision it. Do not assume identifier ownership.
3. Add one Widget Extension per app: FRIMacWidgets, FRIiOSWidgets. Include App Intent configuration. Embed each .appex in its own host. One WidgetBundle entry per extension, stable kind FRIDayWidget. Live Activities are outside this release unless implemented/tested separately.
4. Add local FRICore package to all four targets, FRIDesign where needed, FRICoreTests and UI-test targets. Shared schemes must include extension build dependencies. Enable APPLICATION_EXTENSION_API_ONLY for extensions.
5. Configure owned App Group and matching shared Keychain group, team and profiles. Native Mac is sandboxed; allow network client and user-selected file read/write only where necessary. No broad filesystem exceptions.
6. Add approved icon assets, display names and strict fri://day/YYYY-MM-DD and fri://task/ID routing. Unknown routes show an error; no URL executes commands. Add launch/orientation configuration.
7. Privacy descriptions match implemented permissions. EventKit import needs full calendar access; JSON/ICS imports do not. Manual-city weather/maps need no location permission. No microphone entitlement for deferred Day.
8. Commit project.pbxproj, shared schemes, Package.resolved, entitlements and privacy manifest. Ignore DerivedData, archives, local signing configs and user backups. Install simulator runtimes and connect an unlocked physical iPhone.

## Commands after project creation

These are target paths/schemes to create, not files already present. Confirm names first. Keep signing enabled for device/archive work; simulator-only builds can disable it.

```sh
xcode-select -p
xcodebuild -version
xcodebuild -showsdks
security find-identity -v -p codesigning
xcodebuild -list -project apple/FRI.xcodeproj
xcrun simctl list devices available
xcodebuild -resolvePackageDependencies -project apple/FRI.xcodeproj -scheme FRIiOS
xcodebuild test -project apple/FRI.xcodeproj -scheme FRIMac -destination 'platform=macOS' -resultBundlePath artifacts/mac-tests.xcresult
# Substitute an installed simulator UDID.
xcodebuild test -project apple/FRI.xcodeproj -scheme FRIiOS -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' -resultBundlePath artifacts/ios-tests.xcresult
xcodebuild build -project apple/FRI.xcodeproj -scheme FRIiOS -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

Run each extension with its host in Xcode, then add it through the system widget gallery. Simulator build success is not physical-device widget evidence.

## Existing Electron Mac comparison build

```sh
npm ci --prefix preview
npm run build --prefix preview
npm ci --prefix tests
npm exec --prefix tests -- playwright install chromium
npm ci --prefix desktop
node desktop/node_modules/electron/install.js
npm run prepare:ui --prefix desktop
npm test --prefix desktop
npm run dist --prefix desktop
```

Builder produces arm64/x64 DMG/ZIP; signing is separate. Windows-only modules must gracefully return unsupported, never call Explorer/PowerShell/D3D on Mac.
