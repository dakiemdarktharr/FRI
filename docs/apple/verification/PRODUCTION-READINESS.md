# FRI native production readiness

Status: IN PROGRESS. This is an acceptance ledger, not a release approval.

## User decisions — 2026-11-23

- Implement in Swift/SwiftUI with Xcode.
- Use FRI desktop 0.5 Windows/Linux as the visual and functional reference: `preview/brand.css`, `preview/app.js`, `preview/native.js`, `desktop/`.
- Match the cream/marsala palette, brown sidebar, day card, date tabs, duration mosaic, Up next and service cards. Earlier monochrome HTML prototypes are not the visual target.
- Full desktop 0.5 functionality, including its explicitly local Day conversation. Do not turn the local demo into an unrequested paid AI integration.
- Prioritize macOS; run and interact with the native Mac app on the user's Mac. iOS testing is Simulator-only. Do not access the connected physical iPhone.
- User has no paid Apple Developer Program. Keep WidgetKit for future signed App Group configuration; prioritize standalone Swift/AppKit desktop widget windows on macOS.
- Continue using branch `macos`; commits authored by `ank-less`.

## Release gates

Every item needs observed evidence before being marked PASS. Successful compilation is not runtime or release verification.

| Gate | Status / evidence |
|---|---|
| Native macOS debug build | PASS after initial desktop 0.5 visual rebuild, `/tmp/fri-production-mac.log` |
| Native iOS build after current edits | PASS, Simulator compile 2026-11-23 15:13 UTC; four UI workflows passed across the latest targeted runs |
| Core data regression | 20 local tests passed, 1 opt-in network test skipped in current full run; live network passed separately. Includes imported-draft recovery and source deduplication |
| Mac create/edit/delete/undo | PASS via CUA with isolated synthetic store: create 10:00/60 min, edit Unicode title, delete 11:00/30 min appointment, Cmd-Z restores it |
| Mac overlapping appointments | PASS via CUA: 10:30 conflicts with 10:00–11:00; Change times opens review; 11:00 saves successfully |
| Mac drafts/validation | PASS via CUA: close/reopen retains draft; edit/reopen retains Unicode title; 25:00 is rejected; 14:00 + 45 min completes review |
| Mac relaunch persistence | PASS for three synthetic appointments after quit/relaunch |
| App and widget real shared store | Pending developer team, App Group and Keychain entitlements; synthetic store is not equivalent |
| Signed standalone Mac widget | Small/Large presets and Done PASS on local ad-hoc signed sandbox; free drag/grip resize PASS by direct user confirmation |
| Widget timeline/midnight/lock/long text | Prior core and Simulator preview evidence only; current Mac runtime pending |
| Mac all views, keyboard, accessibility | Pending full matrix; duplicate View menu and low-contrast toolbar found during current visual pass |
| Full visual equivalence to 0.5 | In progress; first native cream/marsala render observed. Sidebar artwork, card variants, service rail, Day and some layout details remain |
| Imports | Mac ICS, CSV, text PDF, scanned PDF and PNG file-picker → review → save PASS; iOS pasted text / missing-date clarification PASS. Public calendar URL and EventKit runtime pending |
| Export/restore file dialogs and Undo | PASS through native Mac file panels: restore exported three-appointment backup, collection removed; Cmd-Z restored collection and calendar |
| Reminders | Five-minute lead and midnight/DST regression PASS; system permission/delivery/cancellation runtime pending |
| Services | Live Weather/Maps success, reopen persistence and disconnect PASS; Spotify link save/canonicalize/disconnect and manual activity bounds/persistence/clear PASS. Offline errors, service rail and Spotify playback pending |
| iOS responsive/UI workflows | PASS for deadline/collection persistence, text import, larger-text editor/restore and six widget previews. See latest result bundles below. Broader matrix pending; Simulator only |
| Signed upgrade and release artifacts | Pending signing; no claim of notarization, App Store, TestFlight or physical-device validation |

## Current runtime isolation

The native debug Mac run uses `FRI_SYNTHETIC_PREVIEW=1` and UUID-scoped `FRI_TEST_STORE_ID`. It does not touch the installed Electron application's calendar. Preview mode is excluded from Release. The fixed synthetic key must never be used for customer calendar data.

## Remaining review matrix

- Empty/populated day, month/year, Today/previous/next, tabs and restored selection.
- Short/long/Unicode titles, narrow window, list/mosaic, large text, high contrast/reduced transparency/motion.
- Batch creation, every missing-info branch, cancel/resume, overlaps with stored and batch plans, edit after concurrent widget completion.
- Single/bulk delete, finish day/reopen, undo after newer edits, import duplicate sources, damaged backup and failed storage paths.
- Search by title/place/notes/category, empty results, keyboard focus and Escape/Close, multiple windows.
- Export from Windows schema then import native; native export then validate with desktop parser.
- Weather/Maps/Spotify/activity connect/disconnect, failed/offline fetch and cache age, no fabricated live data.
- Mac native widgets in every supported family: add, placement, resize, remove, relaunch, date selection, Done and multiple instances.
- Final Release builds, signed entitlements, data-preserving A→B upgrade and distribution verification.

## Standalone Mac widget checkpoint

- Added separate `FRIMac` (standalone) and `FRIMacWidgetKit` (App Group) schemes. The standalone target does not embed a WidgetKit extension and has its own sandbox entitlements without shared access groups.
- The standalone store uses AES-GCM in the app's Application Support directory and the Mac login keychain, with a distinct `FRI.Calendar.Standalone` service. It is an explicit storage mode, never an error fallback. Switching between sandboxed/unsandboxed development containers or standalone/shared configurations requires deliberate backup transfer.
- Real standalone store (no synthetic environment): created a Unicode-title deadline; wrote encrypted calendar bytes; raw file did not contain the test title; parent directory mode was 0700; quit/relaunch retained the appointment.
- AppKit widget: created, Small preset applied (240 × 180), Done changed the real appointment, app relaunch retained Done; reopening it in the app updated the widget back to pending. A 32-point header fix allows the small widget to retain the task, time and date without a large unused header.
- Native drag events reach `NSWindow.performDrag(with:)` when the title is clicked by accessibility index. Coordinate-drag attempts through the CUA tool have not yet delivered a matching drag event or changed the saved frame. Free dragging and grip resizing were subsequently confirmed working by the user on the sandbox build. Do not equate preset resizing with grip dragging. Menu-based directional placement also changed the saved frame by 40 points in the earlier QA run.
- Local ad-hoc signed standalone Mac build succeeded with app sandbox, user-selected file read/write, outbound network and calendar entitlements. User approved Keychain directly. CUA observed `Sandbox widget verification` saved, retained after the next build/relaunch, and completed from the sandbox widget. Small and Large layouts rendered successfully. This validates local sandbox storage and host-owned AppKit panels, not WidgetKit/App Group or distribution signing.
- Mac XCTest: the runner now starts with local signing and hardened runtime disabled in the test command, but enabling automation mode times out. `DevToolsSecurity -status` reports developer mode disabled. CUA manual checks are recorded separately; no XCTest UI pass is claimed.
- Latest core suite before service-card additions: 17 passed, one opt-in public-network test skipped (18 total reported by Swift Testing). Includes full restore undo, concurrent undo protection, five-minute reminder scheduling, midnight/DST and Spotify public-resource validation.
- Day local-rule conversation was exercised: it reported all three pending synthetic plans and created an actual saved “A little walk” draft. Spoken audio has not been verified.
- Review now preserves edited fields when going back from clarification and explicitly asks for a missing date. Services now show loading states, persist weather city, include attribution, and allow clearing manual activity.

## Follow-up verification — 2026-11-23

- Closing the main window leaves the AppKit widget alive; Open calendar successfully recreates the main window. Menu Search/Import/Export/View now reveal the calendar first, reusing its existing window.
- Export Backup opened the native save panel; the user completed Export. The exported JSON contained all three synthetic QA appointments and the `fri-backup` schema 1 envelope. Native restore/Undo round-trip subsequently passed; see additional runtime evidence.
- Keychain preparation moved off the main actor and caches the key only in memory for the store lifetime. The app now displays a responsive opening state during system authorization. Tests cover denied authorization on empty and populated stores and preserve ciphertext on failure.
- Found missing desktop 0.5 Collections flow: added creation, category filtering and clear-filter empty state; Mac and iOS runtime validation subsequently passed. Fixed Solid sidebar still drawing a gradient.
- The latest Mac Debug and iOS Simulator builds succeeded without compiler diagnostics. No physical iPhone was accessed.

- Current iOS regression: `testDeadlineClarificationAndPersistence` and `testWidgetAutoFitAtEverySize` passed, 0 failures; six widget size/text combinations. Result bundle: `~/Library/Developer/MobileBuildMCP/workspaces/MOMO-c7c317bd7fec/result-bundles/test_sim_2026-11-23T14-16-33-380Z_pid22065_7eaedefa.xcresult`.

## Additional runtime evidence

- User directly confirmed both free widget dragging and resizing work. This is user-observed evidence; CUA coordinate gestures did not independently verify the drag.
- Mac standalone and Mac WidgetKit universal Release builds both succeeded. These are unsigned compile checks, not release signing or WidgetKit runtime certification.
- Opt-in live public HTTPS test passed against example.com (0.45 s). All 20 core test cases have now passed across the core run plus the opt-in run.
- Added collection regression to iOS workflow test: creation, empty filtered state, Show all plans and relaunch persistence passed (2026-11-23 14:20 UTC, `test_sim_2026-11-23T14-20-40-929Z_pid22065_6864c665.xcresult`).
- Mac CUA: created Work QA collection; filter showed correct empty state; Show all plans cleared it. Month showed 3 appointments on Nov 23; Year → December opened the correct month.
- Mac CUA restore: selected exported FRI-backup.json via native Open panel; confirmation shown; restoring removed newer collection; Cmd-Z restored Work QA. All actions used isolated synthetic data.
- Live Weather test returned Hanoi temperature, persisted city/cache after closing and reopening Services, and Disconnect cleared it. Live Maps search displayed the Hanoi Opera House marker; saved place survived reopening; Disconnect remained available and cleared it. These were public test queries, not device location access.
- QA Mac now uses compile override bundle ID `com.fri.calendar.native.qa`, derived data `mac-qa-runtime`, to avoid routing input to another native build. It retains the UUID-scoped synthetic test store.

- Earlier checkpoint rendered cream Services dialogs. Direct inspection of the installed desktop 0.5 Settings dialog and brand.css later showed that dialogs should be brown with cream inputs; the later dialog audit below supersedes that palette assumption.
- Spotify link saved with tracking query removed, survived closing/reopening Services, then disconnected. No Spotify login/playback was performed. Manual steps 4,321 saved; 100,001 rejected; reopening preserved 4,321; Clear activity reset to zero.

## Import recovery and review isolation — 2026-11-23

- Fixed a data-loss bug: source-key deduplication discarded clarification edits to an existing imported draft. `CalendarState.stageDrafts` now updates the same draft ID before deduplicating a newly imported source. Regression covers encrypted write/read, revised time/duration, duplicate-source rejection and already committed sources.
- Import completion reviews only newly accepted plan IDs. New-plan Done reviews only the current composition batch; Review saved drafts remains the explicit way to review all saved drafts. Existing unrelated drafts are retained.
- Mac CUA ICS: selected import-review.ics through the native picker; confirmed Nov 24 / Test room; Add to drafts immediately asked for time. Entered 15:30, closed before duration, reopened and observed 15:30 retained. Entered 45 minutes, saved one appointment; A little walk remained a draft.
- Mac CUA CSV: parsed quoted comma title, schedule 09:15/35 minutes and deadline 12:00; accepted both and observed both on Nov 24.
- Mac CUA PDF/image batch: selected image-only PDF, text PDF and PNG together; all produced correct titles, dates and times. After entering 20 minutes each, all three appeared on Nov 25. Controlled fixture evidence only, not a claim of general OCR accuracy. Fixtures and regeneration script are tracked under apple/UITests/Fixtures and apple/Tools.
- iOS text import regression passed: missing source date requires explicit Use today, then duration clarification and save. Result: test_sim_2026-11-23T14-37-54-912Z_pid22065_aec274c7.xcresult (the other test in that run failed on a test scroll gesture).
- iOS deadline/collection regression with a pre-existing unrelated draft passed after correcting the test scroll gesture to avoid the keyboard prediction strip. Result: test_sim_2026-11-23T14-43-59-594Z_pid22065_b370257e.xcresult. Prior failing attempts are not counted as passes.
- Current core suite: 20 passed and 1 opt-in network skip, /tmp/fri-core-import-final.log.


## Dialog parity and reading controls — 2026-11-23

- Directly inspected installed desktop 0.5 Settings alongside preview/brand.css: dialogs are #302929 with light text and cream inputs, not cream dialog backgrounds. Updated the common native sheet and input styles, retaining native text editing. Explicit cream foreground on Marsala primary actions fixes dark text inherited from cream cards.
- Settings now includes the reference appearance/comfort wording, palette swatches and Restore look. Restore look changes appearance only and retains reminders, saved photo and service data. The long reference phrase is a wrapping content heading, with a short Settings navigation title on compact screens.
- Found and reproduced an iOS reading-preference defect: enabling Larger text resized the calendar but not a newly opened editor. Applying the effective Dynamic Type size explicitly at each sheet boundary fixes the presentation inheritance gap. Calendar filters can move to additional rows instead of compressing the labels.
- The month-opening button now exposes the selected full date as its accessibility value. Mac inspection also caught multiline Toggle labels exposing only their subtitles; explicit names now identify Liquid glass, Gentle motion and Larger text. This is AX-tree verification, not a complete VoiceOver audit.
- Mac CUA: native Window → Move & Resize → Left produced a 757-point-wide calendar. The sidebar became a working navigation menu; all three QA cards, date tabs, Add, filters and Done controls remained visible. Settings opened from the compact menu; Larger text toggled on, Restore look reset it off, and Cmd-1 returned to Today. Mac semantic-font scaling still needs a dedicated check: the preference visibly changes card layout, but SwiftUI Dynamic Type alone did not visibly enlarge all Mac form fonts.
- iOS widget preview: all six Small/Medium/Large × normal/large-text states passed again with an explicit assertion that the large-text switch really changed to 1. Result: test_sim_2026-11-23T15-04-21-955Z_pid22065_8763548a.xcresult. The other test in that run failed after a layout change moved its switch outside the materialized Form rows; it is not counted as a pass.
- Earlier new reading-control test attempts exposed test mechanics separately: a partially visible switch row was considered hittable, and tapping its label center did not toggle the native switch. The test now scrolls the complete control into view, taps the actual trailing switch and re-queries after Dynamic Type reflow. No failed attempt is treated as product validation.
- Latest Mac QA build: /tmp/fri-mac-theme-build.log, BUILD SUCCEEDED. Production signing, real WidgetKit shared-store runtime and broader visual/accessibility gates remain open.
- Final iOS workflow run: 3 passed, 0 failed (260.5 s), test_sim_2026-11-23T15-07-34-485Z_pid22065_1d15a9b1.xcresult. Covers deadline/draft isolation/collection persistence; enabling Larger text, observing a larger editor field, saving a deadline and Restore look returning to the original field height; pasted-text import/date confirmation. The larger-text calendar screenshot was reviewed at /tmp/fri-dialog-verified/C25F1A63-A131-4AFA-B3E4-767159C26D63.png: filters reflow and content remains vertically scrollable.
- Final Mac relaunch observed the full Settings heading and corrected Liquid glass / Gentle motion / Larger text accessibility names. Final iOS compile after the label-only correction also passed: build_sim_2026-11-23T15-12-55-962Z_pid22065_83a5056a.log. No core storage code changed in this checkpoint, so the already-passing core suite was not repeated.
