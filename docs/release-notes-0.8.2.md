# Fri 0.8.2 — Choose a time. Confirm.

Windows 0.8.2 · Android 0.4.2 / code 6 · browser calendar and standalone HTML.

## Changes

- Choose exact hours, minutes and AM/PM with an Apple-inspired wheel picker. One full-width **Confirm** button applies the time. Closing the picker leaves the original value unchanged.
- The appointment editor and missing-information card use one **Confirm** action. Escape, the close control and Android Back protect edited drafts before discarding them. Android preserves duration when an ordinary plan's start changes.
- Navigate the calendar, feed, tabs, search results and menus from the keyboard. Use Ctrl/Command+N for a plan, Ctrl/Command+K for search, F6 between areas, and ? for the complete reference. Single-key shortcuts can be disabled in Settings and pause while typing or composing Vietnamese text.
- Focus stays on useful controls after completion, calendar month changes and source refreshes. Hidden mobile navigation is removed from keyboard traversal.
- Create, move, resize and remove desktop widgets from the keyboard. Widget option-menu arrows no longer move the window. Serialized position saves prevent a rapidly removed widget from reappearing after a pending save.

## Verification — 27 November 2026

| Surface | Observed checks |
| --- | --- |
| Windows source | 83/83 tests: native bridge, encrypted storage, source/browser boundaries, calendar/import/Day logic, updates, UI and widget lifecycle |
| Preview | 46/46 Chromium tests, including calendar/import/appearance regression and seven keyboard/time-picker scenarios |
| WebKit | Seven keyboard/time-picker scenarios, including exact minutes, midnight/noon, modal month boundaries, IME guards and draft protection |
| Browser product | Real local image OCR, structured/text sources, missing fields, staged commit, overlap review, persistence and three responsive widths; no outbound upload during the checks |
| Accessibility automation | No WCAG A/AA violations reported by axe for the tested dark time-picker state |
| Windows package | Archive audit: version 0.8.2, canonical recognition and local OCR present; credentials and test sources absent. Packaged keyboard/widget creation, movement, resize, Done, restart and removal checked separately |
| Android build | TypeScript and ESLint pass. Release APKs built successfully for ARM64 and x86_64 |
| Android API 35 emulator | Updated existing install without clearing data. Scrolled 09:00 to 21:03; Confirm retained a one-hour duration (22:03 end). Back canceled an unconfirmed wheel change. Edited-form Back offered Keep editing/Discard. Confirm saved a synthetic plan, which was then deleted. Existing launcher widget survived upgrade and its + opened New plan |

The Android emulator ran without a visible window. Test inputs were synthetic; private calendars and credentials are not fixtures. Package hashes are supplied in the release's `SHA256SUMS.txt`.

## Run and rebuild

See [keyboard and time-picker contract](keyboard-and-time-082.md) for commands and shortcuts, [Android build instructions](../mobile/README.md), and [Apple rebuild contract](apple/09-FIRST-PLAN-REBUILD.md). The Apple handoff specifies the matching interactions; native macOS/iOS binaries were not rebuilt on Windows.

Windows remains unsigned; Android is a development-key local alpha. This release does not certify every possible interaction, physical Android keyboards or a complete NVDA/TalkBack/VoiceOver review. Existing app identity and local data are preserved across upgrades.
