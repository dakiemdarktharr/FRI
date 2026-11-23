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
- Website and remote CI/publication receipts are pending the final validation pass.

## Boundaries

The Windows installer is unsigned. Native glass and icon reflow remain in place; this import change does not claim a new visual audit of every unrelated animation. macOS downloads remain the separately verified public 0.6.0 development builds until 0.6.1 artifacts pass their own checks. Native Apple/Android smart-import parity is not implemented here. Session expiry, MFA, site restrictions, model uncertainty, request limits and insufficient planning capacity remain explicit recoverable conditions. See [privacy](privacy.md).

Windows installer: `FRI-0.6.1-win-x64.exe`, 116991386 bytes. SHA-256: `3500fe65dce33514bddf8f059cd192e00267d3ba1e617235ed0a6f59c378ecf6`.
