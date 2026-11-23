# Acceptance and research register

Every parity row needs implementation path, test ID, observed result and evidence. Pending items stay visible. Compile success alone does not prove parity.

- Clean app+extension builds: exact Xcode/SDK/OS/commit, architectures and deployment floor.
- Windows fixture parity: deadlines, batch/cards, conflicts, imports, availability, concurrent edit/Done, failed writes and restore rollback.
- Real-device widget add/move/remove/size, double Done, app terminated, lock/reboot, midnight/DST, multiple instances, stale/offline services.
- Small/large phone, iPad split view, narrow Mac, large text, VoiceOver/keyboard; no hover-only controls/focus traps.
- Glass moving-backdrop frame sequences, reduced transparency, hidden-window energy, display scales/Spaces.
- Synthetic network/privacy checks: no task content to FRI/providers, consent/disconnect, no secrets in artifacts.
- Signed A→B upgrade retains data/keys/settings/widgets; uninstall doesn't delete exported backups.
- Downloaded Mac DMG notarization/Gatekeeper and iOS TestFlight install/update on device; checksums and exact source commit.

Receipt path: docs/apple/verification/RELEASE.md. Columns: Test / Platform+OS / Steps / Expected / Observed / Evidence / Remaining issue. Publish synthetic footage only.

Research date: 2026-11-23; primary Apple docs and selected library source were read from Windows, not executed in Xcode. Parallel connector required authentication, so direct research was used; no completed Parallel report exists. Recheck changing platform/submission requirements on Mac.

Source index: each guide links primary sources next to decisions. Core references: [Xcode](https://developer.apple.com/xcode/system-requirements/), [WidgetKit](https://developer.apple.com/documentation/widgetkit/), [App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups), [Keychain sharing](https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps), [SwiftUI glass](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views), [AppKit glass](https://developer.apple.com/documentation/appkit/nsglasseffectview), [EventKit](https://developer.apple.com/documentation/eventkit/accessing-the-event-store), [Vision](https://developer.apple.com/documentation/vision/recognizing-text-in-images), [notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution/), [distribution](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases), [Spotify](https://developer.spotify.com/documentation/embeds), [OSM](https://operations.osmfoundation.org/policies/tiles/).
