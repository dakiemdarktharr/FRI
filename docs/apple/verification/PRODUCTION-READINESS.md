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
| Native iOS build after current edits | PASS, Simulator compile 2026-11-23 14:16 UTC; runtime regression in progress |
| Core data regression | 19 passing Swift tests, 1 opt-in network test skipped; includes restore/undo, concurrent edits, Keychain denial and reminder timing |
| Mac create/edit/delete/undo | PASS via CUA with isolated synthetic store: create 10:00/60 min, edit Unicode title, delete 11:00/30 min appointment, Cmd-Z restores it |
| Mac overlapping appointments | PASS via CUA: 10:30 conflicts with 10:00–11:00; Change times opens review; 11:00 saves successfully |
| Mac drafts/validation | PASS via CUA: close/reopen retains draft; edit/reopen retains Unicode title; 25:00 is rejected; 14:00 + 45 min completes review |
| Mac relaunch persistence | PASS for three synthetic appointments after quit/relaunch |
| App and widget real shared store | Pending developer team, App Group and Keychain entitlements; synthetic store is not equivalent |
| Signed standalone Mac widget | Small/Large presets and Done PASS on local ad-hoc signed sandbox; free drag/grip resize PASS by direct user confirmation |
| Widget timeline/midnight/lock/long text | Prior core and Simulator preview evidence only; current Mac runtime pending |
| Mac all views, keyboard, accessibility | Pending full matrix; duplicate View menu and low-contrast toolbar found during current visual pass |
| Full visual equivalence to 0.5 | In progress; first native cream/marsala render observed. Sidebar artwork, card variants, service rail, Day and some layout details remain |
| Imports (ICS/CSV/text/image/PDF/public URL/EventKit) | Core fixtures exist; full Mac interaction matrix pending |
| Export/restore file dialogs and Undo | PASS through native Mac file panels: restore exported three-appointment backup, collection removed; Cmd-Z restored collection and calendar |
| Reminders | Five-minute lead and midnight/DST regression PASS; system permission/delivery/cancellation runtime pending |
| Services | Live Weather/Maps success, reopen persistence and disconnect PASS; Spotify link save/canonicalize/disconnect and manual activity bounds/persistence/clear PASS. Offline errors, service rail and Spotify playback pending |
| iOS responsive/UI workflows | PASS for deadline clarification/persistence and widget auto-fit: 2 XCUITests, 0 failures, 2026-11-23 14:16 UTC. Broader interaction matrix pending; Simulator only |
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
- Export Backup opened the native save panel; the user completed Export. The exported JSON contained all three synthetic QA appointments and the `fri-backup` schema 1 envelope. Native restore dialog round-trip is still pending.
- Keychain preparation moved off the main actor and caches the key only in memory for the store lifetime. The app now displays a responsive opening state during system authorization. Tests cover denied authorization on empty and populated stores and preserve ciphertext on failure.
- Found missing desktop 0.5 Collections flow: added creation, category filtering and clear-filter empty state; runtime validation pending. Fixed Solid sidebar still drawing a gradient.
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

- Services dialogs now use the desktop cream/ink/marsala palette, visually checked on Mac after rebuild; iOS compile passed.
- Spotify link saved with tracking query removed, survived closing/reopening Services, then disconnected. No Spotify login/playback was performed. Manual steps 4,321 saved; 100,001 rejected; reopening preserved 4,321; Clear activity reset to zero.
