# FRI 0.6.1 verification

2026-11-23 · Windows 11 x64 · Asia/Saigon. [Behavior and reproduction commands](smart-import.md).

## Live import checks

- The user's Vietnamese timetable was read by gpt-6-luna through the native import UI. Six courses became six appointments within the confirmed November 23–29 range: one on the 25th, one on the 26th, two on the 27th, one on the 28th and one on the 29th. Five durations were 260 minutes, one was 210. Missing dates triggered range cards rather than an invented semester.
- The isolated test calendar retained all six after restart. Editing a 260-minute appointment preserved its duration and source identity.
- UEH redirected public access to sign-in. The user logged in manually and selected Read this page. A new process restored the session without another login; the installed app also restored it. A bounded related-page pass read 12 pages and extracted 15 entries. All 15 were past and were excluded. Unread links were reported; this does not claim every course or future assignment was enumerated.
- Credentials initially sealed in isolated helper profiles were resealed for the actual FRI profile without logging plaintext. Subsequent installed-app checks confirmed the key and source session were usable. Encryption metadata must accompany ciphertext when restoring a profile.

These live imports were first exercised in the local import candidate numbered 0.6.0, before discovery of a concurrent, different public 0.6.0 release. The candidate upgraded the existing 0.5.0 install, retained its calendar, applied only the existing mono-v1 → fri-v2 branding migration, and added the six real classes. Its [historical receipt](verification/0.6.1/import-candidate-upgrade.json) is not the receipt or hash of the public 0.6.0 release. The combined release is 0.6.1 and retains upstream Day, updater and fractional-DPI widget fixes.

Private images, account/course content, screenshots, keys, cookies and profile backups remain in ignored local storage. Public test fixtures are synthetic.

## Combined-source checks

- Preview Chromium: **28 passed**; includes imports, clarification/draft resume, past filtering, deduplication, overlap consent, assignment work, recurrence/exceptions/cancellations, time zones, overnight boundaries, Day, updater UI, navigation and accessibility.
- Desktop: **66 passed**; includes provider/source restrictions, encrypted persistence, planner, Day/updater and native window/widget operations.
- Preview WebKit: **28 passed**. Packaged EXE: **6 passed**, covering native window, menus, calendar, opaque surfaces, Day and widget create/move/resize/Done/remove.
- Actual installed 0.6.1: calendar/tasks and settings exactly matched the pre-upgrade state; six classes, key usability and authenticated UEH session survived. A further restart retained all six. [Upgrade receipt](verification/0.6.1/installer-upgrade.json).
- Website: 9 interface checks on each engine, zero Chromium axe violations, plus 276 halftone frames. Initial 1.5-second seek waits timed out under load; the review helper now waits up to 5 seconds for decoded seeks and fails instead of capturing stale frames. Sampling frame midpoints avoids browser time-quantization at boundaries. The final 276 captures had zero seek timeouts and no identical adjacent frames; a contact sheet was visually inspected. [Frame measurements](verification/0.6.1/ocean-frames.json).
- Windows WebKit lacks the local media codecs in this environment and uses the poster fallback; its UI tests do not establish video playback. Remote Linux WebKit playback is checked separately by CI. The responsive suite covers six viewport widths.
- Production dependency audits for desktop and preview found zero vulnerabilities. ASAR inspection found all import/Day/update modules and no credentials or project tests.

## Publication

The Windows installer and static review files are published at [v0.6.1](https://github.com/dakiemdarktharr/FRI/releases/tag/v0.6.1). The Windows release asset SHA-256 matches the locally installed artifact; its updater manifest SHA-512 also matches. [PR #2](https://github.com/dakiemdarktharr/FRI/pull/2) merged as `6f7726176bdf77851d44dd66c6fd671f92c58c2a`; desktop source was verified at `2db7febc9fb30ab84374889d5f8920fb0f31df1c`.

[Web CI](https://github.com/dakiemdarktharr/FRI/actions/runs/45190376250) passed Chromium and WebKit. [Desktop/container CI](https://github.com/dakiemdarktharr/FRI/actions/runs/45190376091) passed Windows, macOS Intel and container. Both macOS architectures were built, their app archives passed version/module/credential inspection, and all four archive/DMG hashes matched the updater manifest. [Mac artifact receipt](verification/0.6.1/mac-artifacts.json). These are unsigned development builds, not physical Mac/iOS validation. The separate web review-tool correction is documented in the final main-branch history; the release HTML assets retain their tagged source snapshot.

## Boundaries

The Windows installer is unsigned. Native glass and icon reflow remain in place; this import change does not claim a new visual audit of every unrelated animation. macOS 0.6.1 downloads remain unsigned, unnotarized development builds; authenticated source retention was exercised on Windows only. Native Apple/Android smart-import parity is not implemented here. Session expiry, MFA, site restrictions, model uncertainty, request limits and insufficient planning capacity remain explicit recoverable conditions. See [privacy](privacy.md).

Windows installer: `FRI-0.6.1-win-x64.exe`, 116991386 bytes. SHA-256: `3500fe65dce33514bddf8f059cd192e00267d3ba1e617235ed0a6f59c378ecf6`.

## Web follow-up

The Vercel production alias served commit `dcf95a1cbbb54957718199e86bdc8a9150ab66a1` as READY (`dpl_DCbLxT19P67GMYFAeJfw2dKZZpVN`); nine direct Chromium production checks passed, with zero axe violations. The final web follow-up updates Mac download links and separates footer timeline review from video decoding because WebKit suspends off-screen media. The independent ocean-frame test still requires decoded video and zero timeouts. A flaky Day reload assertion was strengthened to await the save boundary and assert the persisted event and dismissal before reloading; no Day production code changed. Current deployment and final CI links are recorded in the project notes.
