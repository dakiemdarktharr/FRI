# Feature parity ledger

Native Apple implementation is pending for every row. Compare the released Windows artifact as well as source/tests. Record implementation path, test and observed result against each row before claiming parity.

| Behavior | Windows reference | Apple requirement |
|---|---|---|
| Day first, previous/next/today, multiple date tabs | preview/app.js | Restored selection; tabs on Mac/iPad, scrollable dates on iPhone; keyboard/touch support. |
| Month/year, rounded square days, delayed preview | preview/app.js | Same information and transitions; touch opens details, never hover-only. |
| Duration-sized mosaic, equal gaps, detail/edit/delete/Done | preview/app.js/style.css | Stable-ID custom Layout, minimum readable cards, long text and Dynamic Type; persistent completion. |
| New deadline/schedule; batch → Done → missing-info cards → calendar | preview/intake.js/app.js | Preserve drafts, cancel/return and every validation branch; never silently commit incomplete entries. |
| Conflicting times | preview/app.js/planning.cjs | Show clashing intervals and allow explicit time changes; never silently move existing appointments. |
| Find time for a task | preview/planning.cjs, desktop/planning.test.cjs | Port interval merging/clipping and zero-duration deadline semantics; compare golden fixtures including DST. |
| Shared free-time comparison | preview/planning.cjs | Explicit interval-file exchange; live account linking remains future. No title/location/notes in availability exports. |
| ICS/CSV/text/image/PDF/public HTTPS intake | preview/intake.js, desktop/ocr.cjs/public-source.cjs | FileImporter, PDFKit/Vision, source review and errors. Match supported recurrence behavior; do not claim full CalDAV sync. |
| JSON backup/restore | preview/app.js, desktop/store.cjs | Interoperable export, transactional restore, validation and rollback. |
| Calendar/drafts/settings, concurrent widget Done | desktop/store.cjs/core.test.cjs | Protected shared store, interprocess transaction, revision, idempotent Done; no lost edits. |
| Monochrome glass, sidebar image/motion, large text | preview/style.css/gradient.jsx | Same visual hierarchy, local images, reduced motion/transparency and contrast. |
| File/Edit/View/Help, search, shortcuts | desktop/main.cjs | Mac menu/traffic lights; iOS toolbar and menus with equivalent actions, no fake minimize/close. |
| Create/move/resize/remove widget | desktop/widgets.cjs/widget.html | Native WidgetKit gallery/families and OS-controlled placement; optional Mac custom panels are a separate feature. |
| Widget priority | desktop/widget.html | Current task + Done → weekday → date → progress → services → later tasks; omit lower priorities in small families. |
| Reminders | desktop/services.cjs | UNUserNotificationCenter opt-in; reconcile after edit/delete/Done; generic private text default. |
| Weather/Spotify/maps/manual steps | desktop/services.cjs/maps.* | Same consent/disconnect and stale-state handling; widget links into app for interactive providers. |
| Data-preserving upgrades | desktop/verify-upgrade.ps1 | Stable bundle/App Group/Keychain IDs; signed A→B test with app and widgets active. |
| Day | Current user decision | Deferred; no new cloud/voice dependency. |

## Required platform differences

iOS apps cannot draw arbitrary widget rectangles, push other apps' Home Screen icons, or silently add/remove widgets. Mac WidgetKit also uses system families and gallery placement. Explain Add Widget and let the OS manage placement; do not automate Finder icon reflow. [WidgetKit](https://developer.apple.com/documentation/widgetkit/)

Widget extensions are not continuously running browsers. No Spotify iframe, interactive Leaflet map or 30fps shader belongs in their views. Show cached information and Link into the app; Done uses AppIntent. [Interactive widgets](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities)

iOS installation is through TestFlight/App Store or a provisioned development route, not an .exe/.dmg/.pkg. macOS supports a signed/notarized .app in a DMG, optionally a PKG. Updates replace binaries and retain data; never delete the old data container to implement an update.
