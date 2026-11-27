# First-plan release — implementation ledger

Started 27 November 2026 from upstream `25cc294`. Read every new commit since `6c59b0c`: relative-time/fast-send recognition, remembered Mac chat sources, background lifetime, first-run guide and native Mac installer validation. Keep the verified Mac download pipeline intact.

## Decisions

- First success beats a mandatory three-page tutorial. An optional local example is recognizably a sample and never writes events until the normal editor's explicit save.
- Empty, filtered, completed, loading and error states are different. Never invent calendar activity to make the app look populated.
- Preserve Cloud/Ink/Teal and Inter. Add an original, slightly irregular naive mark and pictograms; no noisy font or permanently wiggling controls.
- Hide secondary form detail behind “Location & more”. Keep validation, privacy and source status visible when needed.
- “Add ready plans” replaces the ambiguous Refresh label; ingestion still stages the batch first.
- Windows reads the selected foreground window only; pause keeps the grant and forget removes it. Shared relative-time rules do not invent a clock time.
- Android remains explicit text/image sharing, with local OCR and review. Do not silently port Mac screen monitoring to Android.
- Provide a working `/app/` alongside the marketing demonstration. Browser data lives in this browser; desktop encryption and true desktop glass are native capabilities, not claims about a web page.

## Authoritative implementation

`brand/fri-mark.svg`, `brand/symbols.json`, `brand/first-plan.svg`, `brand/naive.css`, `brand/build.cjs`; `desktop/usage-guide.*`; `preview/app.js`, `feed.js`, `smart-intake.js`; `desktop/meeting-activity.cjs`, `meeting-agent.cjs`, `meeting-prompt.*`; `mobile/src/app/assistant.tsx`, `mobile/src/lib/meeting.ts`; `website/build-browser.mjs`, `browser-runtime.js`.

Version intent: Windows 0.8.0, Android 0.4.0/code 4. Use the same storage identity; upgrades must retain calendars and widget state. No payment or account backend is introduced. The prior native Mac download stays independent until rebuilt and verified on Mac.

## Verification receipt

Observed on Windows 11 and the headless Android API 35 x86_64 Pixel Launcher on 27 November 2026. No personal calendar, authenticated page or API key is committed as a fixture.

| Surface | Observed result |
| --- | --- |
| Windows source | 81/81 automated tests: encrypted persistence, planning/import, source sessions, selected-window lifecycle, trusted prompt IPC and update handling |
| Windows packaged executable | 6/6: native bridge, first-plan sample/cancel/skip/save/restart/Help, opaque controls/glass settings, drawn widget, Done, resize, persisted restart and removal |
| Package audit | Version 0.8.0; canonical recognition rules and local OCR model present; credentials and test files absent |
| Calendar UI | 38/38 tests, including complete deletion returning to the first-plan state |
| Browser product | Chromium and WebKit: empty profile, sample without a write, missing duration, explicit save/reload, conflicting invitation held until corrected, real image OCR, failed-source recovery, widths 375/768/1440; no outbound upload requests |
| Marketing site | Chromium and WebKit: nine motion checks each, six responsive widths, eight product stories at four widths and 90 sampled motion frames; Chromium axe audit had no violations |
| Android code | TypeScript/ESLint pass; five shared invitation/handoff tests, nine Kotlin unit tests and four Room/OCR/share instrumentation tests pass; production dependency audit reports zero known vulnerabilities at this check |
| Android device | Install over 0.3.0 preserved events/preferences/widget IDs. Optional sample and real Android text Share both reached normal review, asked duration, and saved. Launcher pin, moving and resizing tested; Done updated the shared event, the completed-day state was distinct from an empty day, and removing test instance 6 left existing instance 4 intact. |

WebKit on this Windows host cannot decode the bundled H.264 test video; local WebKit media playback was skipped. The Linux browser CI is the media gate. These are sampled motion/interaction checks, not a claim that every possible frame or device has been inspected.

A suspected widget refresh fault was disproved by inspecting each launcher's widget ID and saved filter: the Work-only instance correctly omitted a Personal event while the All-calendars instance showed it. No speculative revision-counter workaround is shipped. Room observations remain the update mechanism.

### Reproduce

```powershell
node brand/build.cjs
npm ci --prefix preview
npm run build --prefix preview
npm test --prefix preview
npm ci --prefix desktop
$env:FRI_TEST_HIDDEN='1'
npm test --prefix desktop
npm run dist --prefix desktop
node desktop/verify-package.cjs
$env:FRI_TEST_EXE=(Resolve-Path dist/win-unpacked/FRI.exe).Path
node --test --test-concurrency=1 desktop/desktop.test.cjs desktop/widget.test.cjs
Remove-Item Env:FRI_TEST_EXE
npm ci --prefix website
node website/build.mjs
node website/verify-product.cjs
$env:FRI_BROWSER='webkit'
node website/verify-product.cjs
Remove-Item Env:FRI_BROWSER
npm run lint --prefix mobile
npm run typecheck --prefix mobile
node --test mobile/scripts/meeting.test.cjs
```

Android build and instrumentation commands are in `mobile/README.md`; use its JDK/SDK variables and build both ABIs separately. Local evidence is in ignored `test-results/first-plan/` and `desktop/test-results/`.

### Distribution boundaries

- Windows NSIS replaces the prior application at the same install location; user data is retained. Package/store restart tests passed. A silent installer was **not** run over the user's personal installation during this turn. This installer is unsigned.
- Android APKs are explicitly local alpha builds signed with the existing development key. x86_64 ran on the emulator; ARM64 is build-only. No physical phone, alternative launcher, store signing or complete desktop integration parity is claimed.
- The Windows assistant uses the exact approved foreground window; it does not port Mac app/domain grants or unsent composer reading. Android remains explicit Share.
- Native Mac/iOS changes require a Mac build and device verification. `docs/apple/09-FIRST-PLAN-REBUILD.md` defines assets, tokens, state transitions, rules, storage, widget behavior and the acceptance matrix. The existing verified native Mac download is preserved.
- The browser calendar has browser-local storage and local image OCR, not native encrypted storage, authenticated website capture, PDF/DOCX ingestion or a cross-device account backend.
- Contest registration, eligibility confirmation and the final PDF/slides/video submission bundle are outside this engineering release; see the MoMo note. No contest submission was performed.

### Final Android launcher receipt

The final optimized x86_64 APK retained the completed Personal event after replacement. The All-calendars widget showed **All done today. +**, while the existing Work-only widget correctly showed **No plans today. +**. Drag-to-Remove deleted only the new instance (ID 6); the pre-existing ID 4 remained. Pin/move/resize used the production provider, not the instrumentation provider. Both final ABIs built successfully. The test-only instrumentation app was uninstalled afterward.

The container build now copies the canonical brand assets/font and shared recognition script, and explicitly includes the HTML shell. Its CI job builds and requests the non-root container. This host has no Docker runtime; CI is the container verification authority.

### Artifact sizes and checksums

`SHA256SUMS.txt` is attached to release v0.8.0. SHA-256 values below identify the actual local outputs, not a build from another machine.

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| FRI-0.8.0-win-x64.exe | 136593371 | `1f4fda22d0194fca44c713b318c35bdbe783ebd6b87049420995bb0046759797` |
| FRI-0.4.0-android-arm64.apk | 41293426 | `691c75cf73666c1fbd548658a7843972164be9ad801e9a4c1f4ecec81a300f24` |
| FRI-0.4.0-android-x86_64.apk | 42311923 | `4f1656cddb128bd244031be03232ee3a37af7cfccb06909ff9726f7fe8be5891` |
