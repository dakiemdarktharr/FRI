# Native Mac 0.8.2 build 8

The standalone SwiftUI app uses the same bundle ID and encrypted storage as native build 7. The Intel and Apple silicon executables ship in one DMG. The website retains the previous Intel Electron installer as a separate download.

| Property | Verified value |
| --- | --- |
| Native source | [fa6fb59](https://github.com/dakiemdarktharr/FRI/commit/fa6fb59) |
| Windows reference | [v0.8.2](https://github.com/dakiemdarktharr/FRI/releases/tag/v0.8.2) |
| Build host | Apple silicon, macOS 26.6.2, Xcode 27.2 (27B52), XcodeGen 2.48.0 |
| Bundle | com.fri.calendar.native.mac, standalone, 0.8.2 (8), minimum macOS 14 |
| [Versioned DMG](../../../artifacts/macos/FRI-0.8.2-build8-mac-arm64.dmg) | 5,148,974 bytes · SHA-256 41d1f669dc872421720f0afde4a8692e66a2e7c6e0f47f96b87482628b220afb |
| [App bundle ZIP](../../../artifacts/macos/FRI-0.8.2-build8-mac-arm64.zip) | Packaged FRI.app · 4,491,230 bytes · SHA-256 f008c2a5a57b45f221435c008c8016ef7b7bafb5464de65b534573f5fdd4f739 |

## Installation and trust

The website labels this as a development preview. Xcode applied an ad-hoc signature. Strict nested signature verification passed on the mounted bundle. Gatekeeper's execution assessment rejected it on the test Mac. Developer ID signing and notarization require an appropriate signing identity. The stable download alias and versioned DMG have identical bytes. Their historical filenames contain arm64. Both Mach-O slices are present.

## Verification

- Xcode compiled Release for the standalone Mac app, the separate Mac WidgetKit host and its extension, and the iOS Simulator compatibility target.
- The FRICore package passed 48 domain tests and 13 design tests. These cover calendar storage, import, detection, widget placement, backdrop behavior and large text layout.
- All 14 distinct native XCTest cases passed on the Mac. The full run passed 13 cases including the opt-in public ICS test. The remaining widget test passed on rerun after querying the AppKit panel's AX dialog role and dragging the panel before selecting Large. It verified movement, resizing, restoration and removal after another relaunch.
- UI coverage included parsing and canceling the sample, replaying it, confirming exactly one appointment, draft preservation, five exact time fixtures including noon/midnight, Escape, search, staged sources across restart, conflict holds, calendar filtering, and the local meeting assistant.
- Build 7 wrote a completed synthetic appointment, an existing draft, the dark theme, a source library entry and a staged batch through its native storage API. Build 8 opened that same encrypted store and verified the contents. The test uses a separate profile and a synthetic key.
- The mounted Release app reached a visible calendar window on Apple silicon using arm64 and, separately, x86_64 under Rosetta. The smoke check matched the running process, bundle URL and CPU architecture. It launched with the first-run view and the chat assistant disabled.
- The mounted DMG contained FRI.app and the Applications link. The installer verifier compared the mounted app to the ZIP. All three bundled Be Vietnam Pro font files matched the canonical bytes.
- The web download chooser passed the local Chromium and WebKit suites (19 checks). Cross-platform reference checks passed 46 preview domain cases and six desktop/mobile cases.

## Coverage boundaries

The distribution target uses standalone AppKit widgets. Signed App Group delivery, real system WidgetKit interaction, physical Intel hardware, manual VoiceOver and an end-to-end trial with real provider accounts were not certified in this release. The app-level macOS tests used isolated synthetic calendars. This build does not publish an iOS app.

Use the [native runbook](../11-082-BUILD-RUNBOOK.md) to reproduce the build. Use the development packaging mode with an ad-hoc app.
