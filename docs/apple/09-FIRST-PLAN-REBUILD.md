# Rebuild the first-plan release on macOS and iOS

Reference: Windows **0.8.1**, Android **0.4.1/code 5**, branch `codex/first-plan-release`, based on upstream `25cc294`. Read `docs/first-plan-release.md` and `docs/appearance-081.md` for the verification receipts. This is an implementation specification, not a claim that the Apple build already contains these changes.

## Start from the existing native application

Use `apple/FRI.xcodeproj` and `apple/project.yml`, not a new wrapper project. Preserve the existing app identifiers, App Group, encrypted store, source sessions, WidgetKit IDs, shortcuts and native Mac installer validation. Do not rename the app's storage container or erase user defaults to make a first-run test pass. Native Mac already has remembered app/site sources and an unsent Zalo composer; retain those features. Windows does not supersede them.

Read `00-START-HERE.md`, then the architecture, WidgetKit and distribution chapters. Inspect the current upstream branch before editing; this specification adds to the latest working native client. Regenerate project membership with XcodeGen after adding assets or sources. Keep the shared recognition script byte-identical to `apple/Packages/FRICore/Sources/FRICore/Resources/meeting-agent.js`.

## Exact identity and surface contract

Canonical assets are `brand/fri-mark.svg`, `brand/first-plan.svg` and `brand/symbols.json`. They are original naive vectors: a slightly irregular f and dot, a small calendar illustration, and restrained uneven pictograms. Use their actual geometry, not an SF Symbol approximation or a new bird logo. `brand/build.cjs` renders the Windows/Android assets. Import SVG/PDF vectors into an asset catalog for Apple; create all required AppIcon sizes from the same mark. Do not rasterize a screenshot of the interface.

| Token | Light | Dark |
| --- | --- | --- |
| Background | #F4F7FA | #14181F |
| Opaque surface | #FFFFFF | #222833 |
| Secondary surface | #EAF0F4 | #2C3441 |
| Text | #172B3A | #F2F4F8 |
| Secondary text | #586D7C | #B3BECE |
| Accent | #087F8C | #75D8CC |
| On accent | #FFFFFF | #14181F |
| Border | #DBE4EB | #465368 |
| Tint | #E0F2F2 | #203D3B |

Update `FRIColors.swift`, `FRITypography.swift`, `FRIWorkspaceView.swift`, `FRICalendarGridView.swift`, `FRIPlanEditorView.swift`, `FRIImportView.swift`, `FRIUsageGuide.swift`, `FRIWidgetContent.swift`, and `FRIDayWidget.swift` as appropriate. Be Vietnam Pro is the brand font. Bundle `brand/fonts/be-vietnam-pro/BeVietnamPro-{Regular,SemiBold,Bold}.ttf` and its OFL notice in each app/extension that needs it; register the correct PostScript names (BeVietnamPro-Regular, BeVietnamPro-SemiBold, BeVietnamPro-Bold). Use 700 for web/display headings, 600 for app titles/actions, and 400 for body. Preserve Vietnamese NFC and NFD diacritics; use line height 1.2–1.25 for headings and 1.4–1.55 for body. Inputs/control borders use #7B8B98 light / #7D8BA1 dark. Selected dark calendar cells use dark #14181F text on #75D8CC, never white on that pale teal. Reference `brand/README.md` for roles. Dynamic Type scales content and allows reflow; native system controls keep system typography. Standard WidgetKit layouts must remain readable at system text sizes.

Cards and controls are fully opaque. Only the main workspace uses native behind-window material on macOS, with solid reduced-transparency fallback. Use existing `FRIWindowBackdrop.swift`; do not add screen recording just for glass. iOS material can composite the app's content but cannot reveal arbitrary other applications. The naive mark does not justify wobbly typography or constantly animated controls. Honor Reduce Motion and Increase Contrast. Keep 44 pt touch targets, visible keyboard focus and VoiceOver labels.

## First value: one invitation becomes a real plan

Replace the mandatory three-chapter first-run guide in `FRIUsageGuide.swift` with an optional interaction. Preserve `fri.usageGuideCompleted`: existing users do not get forced through a tutorial after upgrading. Help can reopen the interaction without resetting their calendar.

1. Show **One message. One plan.**, sample message **Tomorrow at 7 pm, coffee?**, and **Find the plan**. Two unobtrusive alternatives: **Create my own**, **Explore Fri**. No sign-in, Screen Recording, cloud key or calendar permission yet.
2. Find the plan must execute the real shared local parser. Display the resolved local date and 7:00 PM. Mark this state **SAMPLE · NOT SAVED**. Duration is unknown; do not invent 30 minutes.
3. **Review this plan** opens the normal editor with Coffee, tomorrow, 19:00 and missing duration. No database write has happened. **Create my own** opens an empty editor; **Explore Fri** enters the calendar. Escape skips safely.
4. Title, date, start time and duration remain visible. Put location, notes and flexible-time preference under **Location & more**. Keep validation and ambiguous AM/PM/later explanations at the relevant field. Do not hide information needed for informed permission or saving.
5. Save uses normal validation and conflict handling. Only the explicit save inserts the event, then opens its day. Cancel, back, dismiss, app termination and help replay never insert sample data. A crash cannot leave a synthetic appointment in the calendar.

Model this as idle → parsing → preview → editor → saved, with an error state offering manual creation. The sample is transient state, not a database seed or a server response. Keep accessibility focus on the new heading or first required field. The success condition is a useful saved plan, not a tour-completion checkbox. No telemetry is added.

## Useful empty states

- Entire calendar empty: original first-plan illustration; **Make room for your first plan.**; **Create a plan**, **Try a sample**, **Bring a file or link**. No fabricated events or meaningless completion percentage.
- A quiet day in an otherwise populated calendar: **Room for what matters**, **Plan this day**. Subsequent real days remain visible in the continuous feed.
- Filter has no match: **Nothing in this collection** / **No unfinished plans** as appropriate. Offer changing the filter; do not show first-run onboarding.
- Reader produced no upcoming plans: explain that no plans were added and offer **Try another source**; include a concrete parsing error when applicable.
- Loading: retain the last successful content, or show a brief progress indicator on first load. Failure: retry, preserving input.
- Empty widget slot: + opens setup. An empty calendar widget opens plan creation; completion remains disabled without a current plan. Larger widget sizes disclose additional information, not larger text.

## Intake and calendar semantics

Keep staged intake: add a source → local extraction → essential missing-field cards → prepared inbox. Rename the ambiguous **Refresh** action to **Add ready plans**, preserving its implementation semantics. Prepared plans are explicitly not on the calendar yet. Add valid plans, retain conflicting fixed appointments for separate review, deduplicate repeated sources, and omit past appointments. Never silently move a class or meeting. A “later” invitation retains `relativeTime` and leaves exact time/date unresolved. Ask only what is needed for a valid event; do not ask for location when it is optional.

Reference `preview/inbox.cjs`, `import-plan.cjs`, `smart-intake.js`, `planning.cjs`, the shared `meeting-agent.js`, and their tests. The test that imports an invitation at an occupied 19:00 expects a held conflict; only an explicit edit to 20:00 permits insertion. Preserve all-day and timezone semantics from the existing native core; do not copy browser localStorage into the Apple store.

## Assistant: preserve platform strengths

macOS: keep current foreground app/site authorization and composer recognition. Closing the calendar may retain the approved background assistant. Pause retains grants and stops recognition; Forget removes grants. Lock/suspend stops work and invalidates an in-flight result. Switching to an unapproved window cannot trigger a proposal. Show a small non-activating panel, without moving keyboard focus away from chat. Review activates the normal calendar editor; dismissal does not save. Do not retain or upload captured frames or raw chat logs. Ask screen/automation permissions only when the user chooses that feature, explaining the exact source scope.

iOS: implement explicit Share text/image extension; do not claim macOS background monitoring. Read only the user-shared item, bound decoded size, do OCR off the main thread and transfer a single-use draft through the App Group. Review before saving. A share extension must not place raw private message text in a deep-link URL. The Android reference is `mobile/docs/meeting-share.md` and `mobile/src/app/assistant.tsx`.

Windows parity is deliberately narrower for capture: exact selected window ID/title, foreground only; currently recognizes a newly visible sent invitation or confirmed exchange, not the unsent composer. Do not weaken Mac capabilities to match this limitation.

## Widget behavior and distribution

Retain existing WidgetKit extensions and interactive Done action. All app and widget writes use the shared repository and refresh relevant timelines. Priority at larger sizes: current task + Done → weekday → date → progress → configured integrations → upcoming tasks. Empty integration slots are +; never show invented weather or playback. WidgetKit owns native placement and resizing. macOS floating desktop widgets are a separate native feature; do not move Finder icons with unsupported APIs or promise Windows Explorer behavior on iOS.

Use `docs/apple/03-XCODE-BUILD.md` and `07-DISTRIBUTION.md`. Run package tests, Xcode macOS/iOS builds, UI tests and actual widget tests. Run `xcodebuild -list -project apple/FRI.xcodeproj` first to use existing scheme names. Keep native DMG pipeline in `.github/workflows/native-mac-installer.yml`; validate the actual Mach-O architectures, mount the DMG, launch the contained app, and check signature/notarization separately. Never label a renamed ZIP as a DMG. Do not replace the current Mac download with an unverified build. iOS is distributed through device development/TestFlight/App Store, not a desktop installer.

## Acceptance receipt required from the Mac

For each row record OS/device, build/commit, command or interaction, result and screenshot/video/XCResult. Do not mark a row passed from this Windows handoff.

| Scenario | Required result |
| --- | --- |
| Fresh profile / existing profile | Optional sample first run; no forced tour on upgrade; existing events and widgets intact |
| Sample → cancel / skip / force quit | Zero writes |
| Sample → duration → save → restart | Exactly one event on the chosen day |
| Missing date, “later”, ambiguous AM/PM | Visible question; no guessed time |
| Intake with collision | Existing time unchanged; conflict held; explicit correction resolves |
| Repeated import / expired assignment | No duplicate and no past insertion |
| Chat foreground / switch / pause / lock / forget | Only authorized active source can propose; no stale result saves |
| Review notification while typing | Typing focus stays in source until Review |
| iOS text and image Share | Offline read; review required; cancel writes nothing |
| Widget pin, resize, move, Done, remove | Real host behavior; persisted shared data; priority layout; no phantom widget |
| Light/dark, reduced motion/transparency, Dynamic Type | Opaque readable controls and accessible fallback |
| Small iPhone, iPad split view, Mac narrow window | No clipped fields/buttons; keyboard can finish every form |
| Install over previous app | User data and widget IDs survive; no duplicate old application bundle |

Reference screenshots/tests: `website/verify-product.cjs`, `desktop/desktop.test.cjs`, `desktop/meeting-agent.test.cjs`, `desktop/widget.test.cjs`, `mobile/scripts/meeting.test.cjs`. Verification screenshots are generated into ignored `test-results/` directories; reproduce them from source rather than assuming the images are tracked.

Official platform references: [SwiftUI accessibility](https://developer.apple.com/documentation/swiftui/accessibility), [WidgetKit](https://developer.apple.com/documentation/widgetkit), [App Intents](https://developer.apple.com/documentation/appintents), [Liquid Glass](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views), [AppKit nonactivatingPanel](https://developer.apple.com/documentation/appkit/nswindow/stylemask/nonactivatingpanel), [Sharing data with extensions](https://developer.apple.com/documentation/xcode/configuring-app-groups). Recheck availability against the installed Xcode SDK before implementation.
