# FRI 0.6.0 verification

2026-11-23 · Windows 11 x64 · Asia/Saigon. [Behavior and reproduction commands](smart-import.md).

## Observed live behavior

- A user-provided Vietnamese timetable was read by gpt-6-luna through the actual native import UI. Its six courses became six appointments within the confirmed November 23–29 window: one on the 25th, one on the 26th, two on the 27th, one on the 28th and one on the 29th. Five durations were 260 minutes, one was 210. The undated image triggered range cards rather than an invented semester.
- The isolated test calendar retained all six after a process restart. Editing a 260-minute appointment retained both the nonstandard duration and its source identity.
- UEH redirected public access to sign-in. The user logged in manually and selected Read this page. A new process restored the session without another login; the final installed app also restored it. A bounded related-page pass read 12 pages and extracted 15 entries. All 15 were past and were excluded. Unread linked pages were explicitly reported; this is not a claim that every course or future assignment in the account was enumerated.
- Credentials initially sealed in helper test profiles were resealed for the actual FRI profile without logging plaintext. Subsequent installed-app checks confirmed that the key and saved source session were usable. Profile encryption metadata must accompany ciphertext when restoring a profile.
- The installer upgraded the existing registered 0.5.0 application in place to 0.6.0, exiting 0. The encrypted calendar file was unchanged immediately after installation. Opening the new app preserved every existing appointment and all settings other than the pre-existing mono-v1 → fri-v2 appearance migration. Six real timetable appointments were then added in the installed app. [Upgrade receipt](verification/0.6.0/installer-upgrade.json).

Private images, course/account content, screenshots, API credentials, cookies and the pre-upgrade profile backup remain in ignored local storage. Public fixtures contain synthetic data.

## Automated checks

- Preview: **20 passing tests on Chromium and 20 on WebKit**. They cover import clarification/draft resume, past filtering, repeat-import deduplication, fixed overlap consent, assignment work, ICS recurrence/EXDATE/exceptions/cancellation, IANA zones, all-day and midnight boundaries, plus existing navigation, completion, settings, responsive layout and accessibility.
- Desktop: **19 passing tests**, including API error handling and secret isolation, source-link restrictions, encrypted persistence, IPC restrictions, planner, window commands and widget create/move/resize/Done/remove.
- Final packaged EXE: **4 passing native integration tests** covering the window/calendar, opaque surfaces, menus and desktop widgets. Live image and authenticated source checks were also repeated in the installed EXE.
- `npm audit --omit=dev` reports zero vulnerabilities for preview and desktop dependencies at verification time.

## Artifact and boundaries

Windows installer: `FRI-0.6.0-win-x64.exe`, **116,980,487 bytes**. SHA-256: `193d3156129962ffa3c93ff4448333f1629fa6886153aca3f0722b95438fd527`. It remains unsigned; no signing credential is configured.

The glass renderer and icon-reflow adapter are unchanged from earlier native visual checks. This change does not claim a new complete frame-by-frame review of unrelated animations. macOS remains a separately tested 0.5 development download; native Apple and Android smart-import parity is not implemented here. Day is not developed by this release. Session expiry, MFA, site restrictions, AI uncertainty, rate limits and insufficient scheduling capacity remain explicit recoverable conditions.

Publication and CI receipts are recorded below once the verified source is pushed.
