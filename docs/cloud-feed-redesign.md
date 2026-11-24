# Cloud, Ink, Teal — accepted direction

2026-11-24. Supersedes the marsala/bird/mosaic defaults; existing appointments and native glass remain.

- Light default: Cloud `#F4F7FA`, Ink `#172B3A`, Teal `#087F8C`. Dark: `#111D27`, surfaces `#1C2D3B`, text `#EAF2F6`, accent `#64D4D0`.
- Opaque appointment cards and controls. Only the workspace material transmits the real desktop on supported native platforms. Browser preview transmits its own wallpaper.
- Default is a compact, chronological, day-grouped feed. Week, month and year remain available in one view selector. Do not scale cards linearly with duration.
- Day is a circular Ink/Teal wave. Reduced motion and background visibility stop decorative animation.
- Sources live in the sidebar. Reading does not change the calendar. Persist prepared rows, essential answers and provenance locally; show source progress and one question per card.
- Refresh applies all valid ready sources against the latest calendar. Fixed events never move automatically. Keep conflicts and capacity failures in the inbox for separate resolution; import the rest. Deduplicate repeated sources and skip past events.
- Prefer ICS, JSON, CSV, HTML metadata and text parsing; local OCR before optional consented model extraction. Never send existing calendar, credentials or cookies to a model.
- Desktop, website demo, Android and widgets share tokens and information priority. Widget size reveals content rather than enlarging type.
- Main screen stays available to the user; headless tests and hidden emulator are preferred.

## Delivery tracking

- [x] User direction confirmed.
- [x] Intake inbox and refresh semantics implemented; deterministic planner + browser regressions pass.
- [x] Desktop feed, calendar views, Day visual reviewed at 1440 and 390 pixels; native package verified.
- [x] Website/demo/intro/mobile responsive pass.
- [x] Android/widget update and native checks.
- [x] Windows installer, GitHub release and production deployment verified; see release-verification-0.7.0.md.

Figma connector returned reauthentication required. Use repo source and screenshots as reviewable design artifacts until the connection is restored.

## Implementation checkpoint

Prepared sources are persisted separately from appointments. Refresh reserves all fixed plans before scheduling flexible work, even across source batches. Conflicts remain as editable source rows. Partial recurring imports can be retried without duplicating accepted occurrences. A bounded extraction cache saves model calls; original uploaded file bytes are not retained. Source provenance remains in the sidebar after applying.

Local readers now cover ICS, JSON, CSV, dated text, HTML metadata, text-layer PDF and DOCX. Scanned PDFs need image export; protected PDFs need an unlocked copy. Complex images use local OCR followed by optional OpenAI only when necessary. Connection secrets remain in the existing encrypted native vault.

Android 0.2.0 ARM64/x86_64 release builds completed; launcher create/move/resize/Done/removal verified. Figma unavailable due to connector authentication. Main-screen automation has not been used.

### Verification checkpoint · 2026-11-24

- Hidden desktop suite: 69/69 passed. Native min/max/restore checks are deferred to the isolated CI desktop when `FRI_TEST_HIDDEN=1`; calendar IPC, encrypted restart, source readers, widget draw/move/resize/Done/removal all ran locally.
- WebKit preview: 35/35 before the additional cache/cancellation regressions. Intake-specific suite now 6/6 on Chromium, including cache reuse, cancellation and direct ICS links.
- Website: 18/18 across Chromium + WebKit, zero Chromium axe violations. New Cloud palette, source-intake demo and six intro design variants.
- Actual supplied UEH timetable image: 6 extracted class rows, 1 model request, shared date-range questions, 0 calendar changes before Refresh, 6 afterwards in an isolated profile. Durations: one 210-minute class and five 260-minute classes.
- Saved UEH source currently returns `sign-in`; no claim of a still-valid remote session. The browser recognizes reconnection and preserves the encrypted vault. Did not open a login window on the user's screen.
- Local PDF and DOCX worker extraction passed; image-only PDFs explicitly ask for image export. Source bytes are not kept in the extraction cache.
- Android installed over the previous alpha without clearing Room data. Dark-mode contrast and native widget editor colors corrected; final native build and launcher acceptance ongoing.

### Publication checkpoint

Windows 0.7.0 installed successfully over 0.6.1; encrypted user calendar bytes remained unchanged and the seeded upgrade probe retained its deadline and large-text preference. Native Apple work from main was merged without replacing it; Apple currently follows the earlier 0.5 UI, and the updated handoff specifies the 0.7 feed/source contract. PR #3 carries this redesign. Final CI passed on Windows, Intel macOS, Chromium/WebKit, Android source and Docker. Release 0.7.0 is published and the website is deployed. See release-verification-0.7.0.md for receipts and platform limits.

Final intake correction: extraction cache keys include the local date. Refresh still performs local deterministic validation, with no additional model call.
