# Release compilation and bundle receipt — 2026-11-24

Source commit `eaf6ce1c418259380a4118c90d3440b6c5c7801e`, Xcode 27.2 (27B52), Apple Swift 6.4.2. No product code changed in this checkpoint. All builds used `CODE_SIGNING_ALLOWED=NO`; no app was installed or launched, and no physical device was accessed.

| Target | Compilation | Binary slices | Log |
|---|---|---|---|
| FRIMac standalone | PASS | arm64 + x86_64 | `/tmp/fri-release-mac-universal.log` |
| FRIMacWidgetKit + FRIMacWidgets | PASS | arm64 + x86_64 each | `/tmp/fri-release-mac-widgetkit.log` |
| FRIiOS + FRIiOSWidgets, Simulator | PASS | arm64 each | `build_sim_2026-11-24T00-20-09-141Z_pid22065_f0a6b430.log` |
| FRIiOS + FRIiOSWidgets, generic device | PASS | arm64 each | `/tmp/fri-release-ios-device.log` |

No compiler warning/error diagnostics in these logs. Generic-device compilation is not a device run, archive validation or installation. The preceding arm64-only Mac build also passed (`/tmp/fri-release-mac-audit.log`).

`swift test --package-path apple/Packages/FRICore -c release` passed **42 core and 13 AppKit/design tests**; one opt-in public HTTPS test was skipped. Swift Testing reports 43 core test definitions including the skip, plus 13 design tests; the legacy XCTest wrappers report zero and are not the test count. Log `/tmp/fri-release-core-audit.log`. These tests cover encrypted-store integrity/concurrency, parsers, reminders, prepared widget timelines, weather cancellation, layout and independent AppKit panels; they do not exercise signed WidgetKit or the complete Mac app UI.

[Bundle inspection JSON](bundles.json) records seven actual bundles, executable SHA-256, architectures, minimum-OS metadata, App Intent metadata, privacy manifest presence, and the app's Metal library/license. macOS declares 14.0, iOS declares 17.0; oldest-OS runtime remains unverified. Privacy manifest presence is not a completed disclosure audit.

No binary contains the `FRI_SYNTHETIC_PREVIEW` / `FRI_WIDGET_PREVIEW` activation strings or `FRI-Synthetic` / `FRI-Tests/` store-directory strings. Source gates their creation paths with `#if DEBUG`. App binaries retain a preview-label literal behind `calendar.synthetic`; that flag starts false and its sole assignment to true is in the excluded Debug branch. A literal alone is not treated as an active fixture path, and string inspection is not an exhaustive security audit.

All seven strict signature checks fail as expected for unsigned compilation. The shared Keychain identifier expands to `.com.fri.calendar.native.shared`, without a team prefix. `CalendarStore.shared()` rejects this; iOS and the Mac WidgetKit variant are not ready for normal shared-store use. The standalone Mac mode explicitly uses its own login-Keychain path and does not consume that shared-group setting. No fallback key, fictional team, entitlement bypass, credential change or signing claim was introduced. Signed storage, release runtime, notarization, upgrades and distribution remain pending.

Reproduce the compilation from the repository root:

```sh
xcodebuild -project apple/FRI.xcodeproj -scheme FRIMac -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath apple/DerivedData/release-universal-audit \
  CODE_SIGNING_ALLOWED=NO 'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO build
xcodebuild -project apple/FRI.xcodeproj -scheme FRIMacWidgetKit -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath apple/DerivedData/release-universal-audit \
  CODE_SIGNING_ALLOWED=NO 'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO build
xcodebuild -project apple/FRI.xcodeproj -scheme FRIiOS -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath apple/DerivedData/release-device-audit \
  CODE_SIGNING_ALLOWED=NO build
swift test --package-path apple/Packages/FRICore -c release
```

The Simulator build used MobileBuildMCP `build_sim` with Release configuration, `release-ios-audit` derived data and QA Simulator `1FB8B016-13F5-42AC-97B6-31455A6F6365`. App-level runtime and distribution status remain governed by the [production-readiness ledger](../PRODUCTION-READINESS.md).
