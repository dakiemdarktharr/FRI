# Windows / Android build 4 refresh

2026-11-25 · Windows host · source baseline `214c44b`.

## What changed

- Rebuilt the selected-window calendar assistant from the newest shared Apple FRICore recognition rules. Windows keeps offline Vietnamese OCR and explicit review before save. Its UI follows Cloud / Ink / Teal and the saved theme.
- Android 0.3.0 receives explicit text/image shares. Bundled Tesseract reads images locally; the shared deterministic parser proposes invitations. The user supplies missing date, AM/PM and duration before saving. Native validation blocks past, duplicate and overlapping fixed events without overwriting existing plans.
- A shared handoff is consumed once even if Router mounts two assistant screens. Failed shares clear stale candidates. Repeated Photos shares are part of the device check.
- Inter 4.1 is bundled across web, Electron, React Native and native Compose editors. System menus, pickers and Glance widget text retain platform fonts. See [typography rules](../brand/README.md).
- Removed decorative subtitles, repeated headings and descriptions from functional screens. Reduced duplicate Add/Day actions, consolidated download platforms into one chooser, and condensed Android appearance/time controls. Necessary event metadata, validation and provider/billing facts remain visible.
- Compact Windows widget menus remain reachable and scroll within the widget.

## Evidence

Local logs and screenshots are under ignored `test-results/cloud` and `test-results/build4`; they are not user data or release assets.

| Area | Observed result |
| --- | --- |
| Windows source | 78 tests passed after final fixes |
| Preview | 38 tests passed: batch entry, missing fields, overlap review, tabs, search, settings, import, undo, accessibility and updates |
| Windows assistant | Six tests passed, including actual bundled OCR and a synthetic changed video stream through sandboxed IPC to review; selected source revocation and two-window operation covered |
| Windows packaged app | Six checks passed: persistence, IPC isolation, native commands, opaque surfaces, Day state and widget lifecycle |
| Compact widget follow-up | Two packaged checks passed after final scrollable-menu fix: resize, move, complete, restore, remove |
| Web | Chromium/WebKit motion, chooser, pricing, demo and footer checks passed; responsive checks at 320, 375, 390, 768, 1024, 1440 px; Chromium axe found no violations |
| Diagrams | Both engines passed eight sections, four widths and 90 sampled workflow frames, plus reduced motion and pause handling |
| Android source | Lint/typecheck; four parser/handoff tests; nine Kotlin calendar/validation unit tests |
| Android native | Four instrumentation tests passed: offline OCR, one-use tokens, Room/widget observation, completion and rollback |
| Android actual UI | API 35 x86_64 hidden emulator: text Share → review → choose 60 minutes → save; duplicate rejected; Google Photos → system Share → Fri → screenshot text and meeting recognized; repeat share verified |
| Android launcher | Pixel Launcher: pin 3×2, drag to another row, expand to 5×3 (progress appears without scaling text), and remove tested with native touch input |
| Builds | Windows x64 NSIS; Android optimized x86_64 and ARM64 APKs. Android installed in-place over the preceding alpha without clearing storage |

The public site uses `getfri.vercel.app`. Vercel rejected `fri.vercel.app` because another team owns it. The replacement domain is attached to the same project for future production deployments.

## Reproduce

```powershell
npm ci --prefix preview
npm run build --prefix preview
npm ci --prefix tests
npm ci --prefix desktop
node desktop/node_modules/electron/install.js
npm run prepare:ui --prefix desktop
$env:FRI_TEST_HIDDEN='1'
npm test --prefix desktop
npm test --prefix preview
node website/build.mjs
node website/verify-v2.cjs
node website/verify-responsive.cjs
node website/verify-positioning.cjs
```

Build Windows with `npm run dist --prefix desktop`; this refresh used a separate `dist/build4` output and file version `0.7.0.4`, preserving old release artifacts. Pass `FRI_TEST_EXE` to the unpacked `FRI.exe` to run packaged tests. Run `node desktop/verify-package.cjs path/to/app.asar` to check packaged rules, OCR and excluded credentials.

For Android, follow [share build instructions](../mobile/docs/meeting-share.md), then run:

```powershell
adb install -r path/to/FRI-0.3.0-build4-x86_64.apk
adb install -r mobile/modules/fri-android/android/build/outputs/apk/androidTest/debug/fri-android-debug-androidTest.apk
adb shell am instrument -w expo.modules.friandroid.test/androidx.test.runner.AndroidJUnitRunner
```

Use Android's real Photos share sheet for image URI grants. An arbitrary `adb am start` with a MediaStore URI does not grant the receiving app access to that image. The app correctly rejects such access.

## Boundaries

- Windows installer is unsigned. The registered user installation was left intact; this turn tests the packaged executable with isolated profiles, not an installer upgrade over the user's live calendar.
- Android is a local alpha signed with the existing debug key, not a Play Store release. ARM64 compiled but was not executed on physical hardware. Other launchers are not verified here.
- The Windows assistant recognizes confirmed messages in selected windows. Native macOS's unsent-composer/no-focus panel is not claimed as Windows parity. Android uses explicit Share, not screen monitoring.
- No macOS/iOS rebuild was performed on Windows. Existing Apple source and release procedures remain intact.
- Full ocean frame export was not repeated for a typography/control change. The existing video remained unchanged; UI motion timing, workflow frames and responsive layout were rechecked. Windows WebKit cannot play these media codecs, so its playback check remains scoped to Linux/macOS CI.

## Artifact checksums

| Local artifact | SHA-256 |
| --- | --- |
| `dist/build4/FRI-0.7.0-build4-win-x64.exe` | `F0F758747D412D7D9EDB1D5902710712E4FC96C4E13BDDD72EB2F8F170A837D6` |
| `dist/android/FRI-0.3.0-build4-x86_64.apk` | `55EEB6F6D1CEF8DB8BA4AF9C706C95199F6CBD691CF439924AA2F2352F2852FB` |
| `dist/android/FRI-0.3.0-build4-arm64-v8a.apk` | `F3585B739E5A1A6A4F5E00546D0478413041C7093C72506542B1CB25DD60BADE` |
