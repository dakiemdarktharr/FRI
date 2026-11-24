# Signing, installers and safe upgrades

Keep bundle ID, team, App Group and Keychain group stable. Mac direct distribution uses Developer ID Application, Hardened Runtime and necessary entitlements. Sign nested helpers/frameworks/extensions properly; no ad-hoc signing or codesign --deep repair. [Developer ID](https://developer.apple.com/help/account/certificates/create-developer-id-certificates).

The current direct-Mac scheme is `FRIMac`: it produces `FRIMac.app`, uses standalone encrypted storage and AppKit desktop widget windows, and embeds no WidgetKit extension. `FRIMacWidgetKit` produces `FRIMacWidgetKit.app` with the shared-store extension. They use the same configured Mac bundle identifier; choose one distribution mode and verify any storage migration before switching an installed product. The WidgetKit variant still requires the owning team's shared App Group and Keychain configuration.

The [current Release compilation receipt](verification/release-build-2026-11-24/README.md) covers both Mac architectures, both Mac schemes, and iOS Simulator/device compilation. These unsigned outputs are not installers or signed release artifacts. The export-option plist paths below must be generated from the actual team's current Xcode export configuration before running export.

For the standalone Mac distribution:

```sh
mkdir -p artifacts
xcodebuild archive -project apple/FRI.xcodeproj -scheme FRIMac -configuration Release -destination 'generic/platform=macOS' -archivePath artifacts/FRIMac.xcarchive
xcodebuild -exportArchive -archivePath artifacts/FRIMac.xcarchive -exportOptionsPlist apple/ExportOptions-Mac.plist -exportPath artifacts/mac
codesign --verify --strict --verbose=2 artifacts/mac/FRIMac.app
codesign -d --entitlements :- artifacts/mac/FRIMac.app
```

Generate/review export options for current Xcode, developer-id method and real team/identities. Inspect .appex signatures individually. Package signed .app + Applications shortcut in DMG. Optional PKG requires Developer ID Installer (different certificate). Data stays outside install directory. [Packaging](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution).

```sh
xcrun notarytool submit artifacts/FRI-mac.dmg --keychain-profile FRI_NOTARY --wait
xcrun stapler staple artifacts/FRI-mac.dmg
xcrun stapler validate artifacts/FRI-mac.dmg
spctl --assess --type open --context context:primary-signature -v artifacts/FRI-mac.dmg
shasum -a 256 artifacts/FRI-mac.dmg
```

Create FRI_NOTARY locally with notarytool store-credentials; never commit secrets. Inspect rejection logs. Test quarantined browser download on another standard-user Mac, Gatekeeper and offline launch. [Notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution/), [workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

Downloading does not remove a running app. Replace binaries after verified download and explicit install/restart; retain data/key containers. Test A→B with active widgets, settings/imports and partly completed day, plus interruption/rollback. Never recursively delete user folders by name. Electron Mac needs supported signed updater; native Mac needs audited updater or signed DMG replacement; App Store uses store updates. Do not mix incompatible signing identities.

## iOS/iPadOS

Create App Store Connect record/identifiers under real team. Archive with embedded widget; OS manages installation/updates, no desktop uninstaller. Development IPA needs provisioning and is not public release.

```sh
xcodebuild archive -project apple/FRI.xcodeproj -scheme FRIiOS -configuration Release -destination 'generic/platform=iOS' -archivePath artifacts/FRIiOS.xcarchive
xcodebuild -exportArchive -archivePath artifacts/FRIiOS.xcarchive -exportOptionsPlist apple/ExportOptions-iOS.plist -exportPath artifacts/ios
```

Generate export options from current Xcode-supported keys. Upload via Organizer/current supported route, TestFlight on real devices, then App Review. Supply privacy details, screenshots, age rating, support/privacy URLs, export compliance and notes explaining local data/widgets/providers. [Distribution](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases).

Premium is 50,000 VND/month, not purchasable yet. Future iOS digital subscriptions require compliant StoreKit setup/verified entitlements. No fake purchase or hard-coded premium status; review current rules before enabling payments.
