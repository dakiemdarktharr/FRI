# Build and distribution runbook for the Mac

Run from the repository root after reading [the implementation plan](10-082-REBUILD-PLAN.md). Scripts produce evidence under ignored `apple/artifacts/`; they do not publish a release, replace an installed app, reset a Simulator or change the current Mac download. The 0.8.2 UI must be ported before these builds can be called equivalent.

## 1. Tools, baseline and resources

Install full stable Xcode supported by the host, the intended iOS Simulator runtime, XcodeGen, Node 22+ and Python 3. Select the full Xcode developer directory. Inspect `xcodebuild -version` and `xcodebuild -showsdks`; do not infer the installed SDK from older receipts. The project currently targets macOS 14 / iOS 17 with Swift 6. If Metal compilation reports a missing toolchain, use Xcode's component installer (`xcodebuild -downloadComponent MetalToolchain`) as directed by that Xcode version.

```sh
node apple/Tools/rebuild-handoff.cjs check
bash apple/Tools/rebuild-on-mac.sh doctor
node apple/Tools/rebuild-handoff.cjs receipt
```

The prepared catalog is `apple/Handoff/Assets.xcassets`. Merge its individual AppIcon, FRIMark, FirstPlan and FriSymbol* sets into `apple/FRI/Assets.xcassets`; retain unrelated existing sets. For widget use, give the extension access to the required catalog or a common resource package; do not assume the host asset catalog is visible from an extension. The iOS icon is opaque square artwork; macOS icons keep the approved rounded silhouette. Render from canonical vectors again only if necessary:

```sh
npm ci --prefix tests
npm exec --prefix tests -- playwright install chromium
node apple/Tools/rebuild-handoff.cjs assets
# Only after reviewing intended changes:
node apple/Tools/rebuild-handoff.cjs manifest
node apple/Tools/rebuild-handoff.cjs check
```

Copy the three canonical `brand/fonts/be-vietnam-pro/*.ttf` files and `OFL.txt` into a FRIDesign resource folder, add its SwiftPM `.process("Resources")` declaration, and register fonts in each process before using the PostScript names. Do not duplicate WOFF2 into native bundles. Use `.custom(..., size:, relativeTo:)` on iOS and preserve the current Mac reading-size scale. Check native-control fallbacks and VoiceOver separately.

After adding/removing Swift files, a Share Extension, resource memberships or target settings:

```sh
bash apple/Tools/rebuild-on-mac.sh generate
git diff -- apple/project.yml apple/FRI.xcodeproj
```

Commit both the specification and generated shared project changes. The current scripts do not regenerate the Xcode project implicitly, so local edits cannot be overwritten unnoticed.

## 2. Build and test before signing

```sh
bash apple/Tools/rebuild-on-mac.sh unit-test
bash apple/Tools/rebuild-on-mac.sh build
# Builds standalone Mac + Mac WidgetKit, arm64/x86_64, and iOS Simulator.
# Unsigned compilation does not establish Keychain or WidgetKit runtime access.

xcrun simctl list devices available
bash apple/Tools/rebuild-on-mac.sh ios-test SIMULATOR_UDID
bash apple/Tools/rebuild-on-mac.sh mac-test
```

`ios-test` validates that the UDID belongs to an installed iOS Simulator and never chooses a physical phone. Tests must use a unique `FRI_TEST_STORE_ID` and Debug-only `FRI_SYNTHETIC_PREVIEW=1`, following the existing XCTest fixtures. Keep permissions opt-in tests separate; do not import personal EventKit calendars for regression fixtures. `mac-test` uses the configured test signing; if the runner cannot attach, record the failure, repair signing on the Mac, and rerun. Do not replace a failed UI test with a build-only PASS.

Port the first-run test that currently expects three Vietnamese guide chapters. Preserve domain tests and remove no test merely because a new interface makes it fail. Add native assertions for all cases in `apple/Handoff/acceptance.json`; use `interaction-fixtures.json` for exact minutes, clamped months and Vietnamese diacritics. Reproduce references from `FRI-liquid-glass.html` locally if needed. Full-device VoiceOver and signed widget checks remain explicit manual gates.

Cross-platform reference checks:

```sh
npm ci --prefix preview
node preview/build.mjs
npm test --prefix preview
node --test desktop/widget-persistence.test.cjs
node --test mobile/scripts/meeting.test.cjs
```

The Node widget race test uses mocked native plumbing and deliberately delayed persistence. The real AppKit and WidgetKit tests must exercise the corresponding native data path too.

## 3. Signing configuration

Without a paid team, a standalone Mac build and a clearly labeled local DMG can still be prepared:

```sh
bash apple/Tools/rebuild-on-mac.sh local-app
# Use the actual app path printed above; this does not install or launch it.
bash apple/Tools/package-native-mac.sh /absolute/path/to/FRIMac.app --development
```

Xcode applies an ad-hoc signature to the standalone target using its existing standalone entitlements. The packager verifies that signature and writes a `-development.dmg`; it does not bypass Gatekeeper or repair a broken signature. This path does not establish WidgetKit provisioning, Developer ID trust or notarization and must not silently replace the public download. Test with isolated synthetic profiles before any data-preserving upgrade trial.

Copy `apple/Handoff/Config/Local.xcconfig.example` to ignored `apple/Config/Local.xcconfig`. Use the owning developer team's existing identifiers and signing prefix. Verify App Group and Keychain entitlements for **each host and extension**. `FRIMac` uses standalone storage; `FRIMacWidgetKit` uses shared storage. Do not change that mode in an installed product without a tested migration. The current user may have no paid developer team: continue compile/Simulator/development work, but record the exact signing gates that cannot be completed.

Copy the export plist examples to `apple/Config/ExportOptions-Mac.local.plist` and `ExportOptions-iOS.local.plist`. Replace the team placeholder. Compare the keys with **the installed** `xcodebuild -help` and an Organizer-exported plist; examples are not provisioning profiles. Automatic signing still needs valid identities/profiles in Xcode/Keychain. Do not commit certificates, `.p12`, profiles, App Store Connect keys or passwords.

Increment marketing/build values consistently for hosts and extensions in `apple/project.yml`, regenerate, and inspect the resulting built Info.plists. Preserve native bundle IDs. A Windows version number alone is not a native App Store build number.

## 4. Archive and export locally

```sh
bash apple/Tools/archive-on-mac.sh mac "$PWD/apple/Config/ExportOptions-Mac.local.plist"
# To deliberately archive the separately provisioned WidgetKit variant:
FRI_MAC_SCHEME=FRIMacWidgetKit bash apple/Tools/archive-on-mac.sh mac "$PWD/apple/Config/ExportOptions-Mac.local.plist"
bash apple/Tools/archive-on-mac.sh ios "$PWD/apple/Config/ExportOptions-iOS.local.plist"
```

The archive script refuses unfilled examples and export options that upload automatically. Set the real signing configuration first. It retains archives, logs and exported bundles in a new directory. Native arm64/x86_64 slices must be inspected in exported Mac bundles; building both earlier does not prove export retained them.

## 5. Mac DMG and upgrade

```sh
# Substitute the real exported app path printed by the archive step.
bash apple/Tools/package-native-mac.sh /absolute/path/to/FRIMac.app
```

The default mode checks the exported app's Developer ID signature, records architectures, and creates a real DMG with FRI.app and an Applications link. It never mutates the original bundle or installed app. It deliberately refuses an ad-hoc app for this distribution path; `--development` is the separate local testing path described above.

Using a Keychain profile already configured on the Mac:

```sh
xcrun notarytool submit /absolute/path/to/FRI-version-build-mac.dmg --keychain-profile FRI_NOTARY --wait
xcrun stapler staple /absolute/path/to/FRI-version-build-mac.dmg
xcrun stapler validate /absolute/path/to/FRI-version-build-mac.dmg
spctl --assess --type open --context context:primary-signature -v /absolute/path/to/FRI-version-build-mac.dmg
shasum -a 256 /absolute/path/to/FRI-version-build-mac.dmg
```

Use the **post-stapling** hash for distribution. Mount read-only, inspect both app and Applications link, validate nested signatures, and test quarantined download/launch under a standard-user account. Test replacing the previous version after quitting Fri: events, sources, appearance, partial completion and widget identities must survive. Downloading an installer must not delete a running app or any calendar/keychain container. Native auto-update is a separate implementation; do not claim Electron's updater is already present in SwiftUI.

The existing `apple/Tools/update-macos-installer.sh` scans `artifacts/macos/FRI-X.Y.Z-buildN-mac-arm64.zip`, requires a root `FRI.app` with matching metadata and native bundle ID, and updates the latest DMG. **Only place a verified build into that publication folder when ready to change the download.** The workflow runs automatically for matching artifacts on main. Keep the last working download until the new signature, launch, upgrade and hash checks pass.

## 6. iOS distribution and final receipt

iOS uses development provisioning, TestFlight or App Store installation; a DMG is not an iOS installer. Inspect the exported app/archive for embedded extensions, privacy manifest, resources and matching versions. Upload through Organizer or an explicitly authorized current Apple distribution route, then test the provisioned build through that channel. Simulator checks do not certify signed App Group access or physical-device widget behavior.

Fill the generated receipt with actual results and evidence paths, including remaining blocked/skipped rows. Add a Markdown summary under `docs/apple/verification/` and publish only synthetic screenshots/log excerpts. Report file names, byte sizes, SHA-256, signing/notarization status, tested OS/device, source commit and upgrade behavior. Update Obsidian if a vault exists; repository docs remain sufficient without it.

Official references: [Xcode requirements](https://developer.apple.com/xcode/system-requirements/), [distribution-signed Mac code](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac/), [packaging](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution), [notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow), [beta and release distribution](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases). Verify export keys with local Xcode rather than relying on historical examples.
