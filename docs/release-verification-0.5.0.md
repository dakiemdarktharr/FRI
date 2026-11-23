# Fri 0.5.0 verification

Date: 2026-11-23, Asia/Saigon. Windows 11 x64.

## Windows

The final local packaged EXE passed 15 native tests: CRUD/persistence, restricted IPC, encrypted restart, planning, widget create/move/resize/Done/remove and opaque surface regression checks. A larger widget retains the same task font size while revealing integrations; smaller sizes hide lower-priority content. Empty slots expose add actions. Main workspace CSS remains translucent; cards/buttons/dialog backgrounds are opaque and dialog backdrop filters are disabled. The actual Direct3D lens implementation is unchanged from the separately observed 0.4.0 test.

The final 0.4.0 → 0.5.0 installer test exited 0 twice, preserved calendar/settings, removed a deliberately obsolete program file and left one registration. [Upgrade receipt](verification/0.5.0/installer-upgrade.json).

| Artifact | 0.4.0 bytes | 0.5.0 bytes | Reduction |
|---|---:|---:|---:|
| Windows installer | 125,483,150 | 116,943,574 | 6.8% |
| Unpacked application | 387,488,471 | 337,372,537 | 12.9% |

Installer SHA-256: `cb0dc30268d7c510c97d6d616678157b87f4313e1f4e9880686c981347ee0ab6`.

The reduction comes from keeping en-US/en-GB Electron resources for the English UI and maximum installer compression. Native glass, widgets, maps, playback integrations and existing calendar functions remain. No universal CPU/RAM performance percentage is claimed.

## Website

Chromium and WebKit each passed eight interaction checks. Chromium also passed six responsive widths (320–1440 px), muted autoplay and automated WCAG A/AA checks with zero reported violations. The new story diagrams replace FAQ questions; reduced-motion alternatives and the animation control remain. A prior run of the unchanged ocean renderer also reviewed 276 consecutive frames at 30 fps.

The current desktop walkthrough was recorded for 0.4.0. Its operations remain valid, but it does not yet show the redesigned 0.5.0 layout. A new real-desktop recording was interrupted by Windows Security's adb prompt; it has not been represented as complete. Private desktop captures are not committed.

## Android and remaining coverage

See [Android verification](../mobile/docs/verification.md) for separate build/device status. A successful local alpha is not a store release or proof of full desktop parity.

Initial CI found two test-harness assumptions: the new brand test expected a pre-existing output directory, and the larger widget started against a screen edge on smaller runners. The tests now create their own directory and leave room for the explicit keyboard move/resize assertion. The app's edge clamping was working correctly.

Physical Android launchers, physical iPhone Safari, macOS signing/notarization and native Apple widgets remain distinct checks; do not infer them from Windows tests. Desktop/container CI run 45149428442 passed on Windows, macOS and Linux container. Web CI run 45149428787 passed on Chromium and WebKit. These runs use e449aa0; subsequent Android and download-link changes receive their own final CI run. Publication receipts are below.

## Final CI and publication

- Final source: f90cf250d6ac198b3dbeb6e863f42ffe1d8f49a2, merged through [PR #1](https://github.com/dakiemdarktharr/FRI/pull/1).
- [Desktop/container CI](https://github.com/dakiemdarktharr/FRI/actions/runs/45157763342), [web CI](https://github.com/dakiemdarktharr/FRI/actions/runs/45157763021) and [Android source CI](https://github.com/dakiemdarktharr/FRI/actions/runs/45157763827) passed. Native Android device tests were local and are documented separately.
- [Public desktop release v0.5.0](https://github.com/dakiemdarktharr/FRI/releases/tag/v0.5.0): all 15 uploaded assets matched local SHA-256 digests; both update manifests matched their files. The Windows EXE is the locally tested package. macOS artifacts are from passing run 45149428442; desktop/preview source is identical between e449aa0 and f90cf25.
- Android APKs remain local; no APK/store publishing occurred.
- Production: https://fri-acne-a6cd.vercel.app . Deployment receipt: dpl_HCrdBB4QwGWxckXcZtNgieyMyxFz; main b8d8aaa877a5b326c2997796b0d7046bbc40834d; READY, production. Live verification checked all eight sections, six widths, pricing, muted autoplay and Chromium accessibility.
