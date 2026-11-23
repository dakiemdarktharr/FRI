# FRI Apple development verification

Date 2026-11-23. Xcode 27.2 (27B52), macOS 26.6.2 on Apple silicon, iOS Simulator 27.2. Deployment targets are iOS 17 and macOS 14. The release workflow requires signing and real-device verification. This receipt records development checks.

## Build and run

Open `apple/FRI.xcodeproj` and select `FRIMac` or `FRIiOS`. Both schemes build their WidgetKit extension as a dependency. The project is tracked. Re-run `xcodegen generate --spec apple/project.yml` with XcodeGen 2.48.0 after changing the project specification or target file membership. The Swift package is local and has no pinned remote dependencies.

For a local Debug run without a developer team, set `FRI_SYNTHETIC_PREVIEW=1` in the scheme’s Run environment, or supply it via the command line. This mode uses a distinct, app-private fixture store and a synthetic key, visibly labels the window and does not exercise widget access. Use synthetic data. The mode is excluded from Release builds.

```sh
swift test --package-path apple/Packages/FRICore
FRI_VERIFY_PUBLIC_NETWORK=1 swift test --package-path apple/Packages/FRICore

xcodebuild build -project apple/FRI.xcodeproj -scheme FRIMac \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath apple/DerivedData/mac CODE_SIGNING_ALLOWED=NO
FRI_SYNTHETIC_PREVIEW=1 apple/DerivedData/mac/Build/Products/Debug/FRIMac.app/Contents/MacOS/FRIMac

xcrun simctl list devices available
xcodebuild test -project apple/FRI.xcodeproj -scheme FRIiOS \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' \
  -parallel-testing-enabled NO -resultBundlePath apple/artifacts/ios-ui.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

For shared storage, add an ignored `apple/Config/Local.xcconfig` with the owning Apple Developer team configured in Xcode. Override `DEVELOPMENT_TEAM`, `FRI_BUNDLE_PREFIX`, `FRI_APP_GROUP` and `FRI_KEYCHAIN_GROUP` as required by the team's registered identifiers and signing prefix. Both hosts and their extensions must have the same App Group and Keychain access group. Verify the signed entitlements on all four bundles. Development bundle IDs use `com.fri.calendar.native`; existing Electron data transfers via JSON backup.

## Recorded results

- Release compilation passed for the macOS app and WidgetKit extension with both arm64 and x86_64 slices. Release compilation also passed for the iOS Simulator and the generic iOS-device target with the widget embedded. The builds used local or disabled signing.
- Ten Swift checks passed with the public HTTPS smoke test enabled. The domain and planning JavaScript comparison suite passed 17 checks.
- The iPhone 18 Pro Simulator UI test passed deadline creation with a missing-time question, restart and search, opening the result and toggling Done and pending. The Mac app opened its day view and New Schedule form.
- A local two-process storage probe retained 50 title changes and an idempotent Done across 50 completion requests. The final revision was 52. The probe exercised the same encrypted store and lock with a synthetic key.
- Local output is under `apple/artifacts/verification/`. It contains Xcode build logs, the successful iOS `.xcresult`, the Mac runner failure log, the Swift test log and a synthetic iPhone Simulator capture.

## Acceptance ledger

| Behavior | Implementation and evidence | Observed and remaining |
|---|---|---|
| Day navigation, previous/next/today, date tabs | Workspace and calendar session | Mac app reached the day workspace. Tab restoration and keyboard traversal need exercised coverage. |
| Month/year and date details | Calendar grid with per-day counts, Mac help preview and day selection | Builds on both platforms. Touch, keyboard and all viewport states need manual verification. |
| Duration mosaic, edit/delete and Done | Design package, detail editor and transactional calendar methods | Unit conflict/duration checks and iOS deadline UI passed. Rich card layout, bulk delete and undo need end-to-end coverage. |
| New deadline/schedule, drafts and missing information | Plan editor, persistent drafts, per-field clarification | iPhone Simulator passed creating a deadline without a time, answering the prompt, relaunching and finding the saved deadline. Opening the search result and marking it Done and pending both passed. Batch, draft cancel/resume and editor error paths need UI coverage. |
| Overlap handling | Interval check and explicit Keep Both or Change Times | Unit overlap/adjacency checks passed. UI conflict decision needs exercise. |
| Find time for a task | Ported clipped and merged minute intervals, ignores deadlines | Swift and JavaScript interval fixtures passed. |
| Compare shared free time | `fri-free-time` v1 JSON, interval-only fields and time-zone offsets | Fixture passed, including offset handling and exclusion of titles. |
| Plan imports | ICS, CSV, text, ImageIO/Vision, PDFKit, direct public HTTPS and EventKit | Swift fixtures passed for folded/duplicate ICS, skipped and repeated DST times, CSV quoting and JSON-LD. Public HTTPS TLS, filtering and response checks passed. Vision/PDF and EventKit UI permissions need verification. Recurrence uses the occurrences present in the source. |
| Backup and restore | `fri-backup` schema 1 and encrypted pre-restore snapshot | Swift tests passed for legacy tasks/settings, protected pre-restore state and corrupted ciphertext. File picker export/import still needs both-platform UI coverage. |
| App/widget shared storage and concurrent Done | App Group, Keychain sharing, AES-GCM and an interprocess lock | Swift tests passed for overlapping edits, repeated Done and deleted IDs. A two-process probe also passed. Signed App Group/Keychain access still requires the team. |
| Monochrome glass and responsive design | SwiftUI and under-window AppKit material with reduced-transparency fallback | Mac window and editor opened. Optical comparison, narrow phone/iPad, VoiceOver and measured performance remain pending. |
| Search, keyboard, menus | Native SwiftUI menus, commands and search | iPhone search after relaunch passed. macOS XCTest runner was killed before connection both with signing disabled and local ad-hoc signing. Direct Mac inspection reached the New Schedule form. |
| Widget placement and lifecycle | Widget gallery instructions, families and configuration | Both WidgetKit extension targets build and are embedded. Actual gallery placement, size changes, lock, relaunch, multiple widgets and real-device Done need verification. |
| Widget priority and timelines | Next task and Done, weekday/date, completion, cached services and later tasks | Provider and AppIntent compile. System rendering, accessibility, refresh and midnight need signed runtime verification. |
| Reminders | UserNotifications opt-in with generic copy, reconciliation and completion cancellation | Permission, delivery and extension-side cancellation need device verification. |
| Weather, Maps, Spotify and steps | Open-Meteo cache, native MapKit, Spotify public deep link and local steps | Provider journeys not verified here. Spotify uses the public link workflow and does not offer the desktop embedded player. |
| Data-preserving upgrade and distribution | Stable configurable identifiers and pre-restore snapshot | No valid code-signing identity was present and only a simulated iPhone was connected. Signed upgrade, notarization, TestFlight and release checksums remain pending. |
| Day | Deferred in the handoff | No Day feature was added. |

The privacy manifest records the calendar-store file timestamp and document metadata uses, with reasons for the app container and user-selected files. [Apple required-reason API reference](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)
