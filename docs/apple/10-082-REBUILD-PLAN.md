# Native Apple port — Windows 0.8.2 / Android 0.4.2

Baseline: `d31f0077745b85941b4fdd4e1bc3009de1e6a82b`, 27 November 2026. This is an implementation plan based on inspected source, not a native parity certification. Start from the existing SwiftUI project. Preserve native imports, EventKit, encrypted storage, assistant authorization, reminders, services, AppKit widgets and WidgetKit extensions.

## Actual targets and storage modes

| Scheme | Product / storage | Use |
| --- | --- | --- |
| FRIMac | FRIMac.app; standalone encrypted store; AppKit floating widgets | Current direct Mac distribution, build 7 |
| FRIMacWidgetKit | FRIMacWidgetKit.app; shared App Group/Keychain; FRIMacWidgets extension | Separate team-provisioned WidgetKit variant |
| FRIiOS | FRIiOS.app; shared App Group/Keychain; FRIiOSWidgets extension | iPhone/iPad Simulator, then provisioned devices/TestFlight |

Both Mac schemes currently resolve to the same configured bundle ID. Do not install one over the other until an explicit storage migration is implemented and tested. `FRI_BUNDLE_PREFIX`, `FRI_APP_GROUP`, `FRI_KEYCHAIN_GROUP` come from `apple/Config/Base.xcconfig` plus ignored `Local.xcconfig`. Keep the installed identities. Native data is not the Windows Electron ciphertext; interchange uses validated export/import.

## Gap map from inspected source

| Area | Existing Apple implementation | Required port / exact reference |
| --- | --- | --- |
| Colors | FRIDesign/FRIColors.swift has old navy dark tokens | Apply Handoff/design-tokens.json; add separate control-edge role. Check selected dates, disabled buttons, focus and service labels |
| Typography | FRIDesign/FRITypography.swift resolves system fonts | Register bundled BeVietnamPro Regular/SemiBold/Bold in each app/extension process; retain Dynamic Type and macOS reading-size behavior |
| Identity | Existing FRIMark/AppIcon catalogs predate naive identity | Merge Handoff/Assets.xcassets AppIcon, FRIMark, FirstPlan, FriSymbol* into the real catalog; preserve DayBackdrop and other current resources |
| Onboarding | FRIUsageGuide.swift still has a mandatory multi-page guide; its XCTest expects Vietnamese chapters | Implement optional sample -> local parser -> preview -> review -> explicit Confirm; cancel/skip/quit makes zero event writes. Update corresponding XCTest, preserve completed-guide preference |
| Editor | FRIPlanEditorView.swift has Add another, Done, freeform time, and onDisappear saves drafts | One full-width Confirm. Separate temporary time selection from committed editor value. Dirty-close guard. Sample cancel must not persist a draft or event; preserve intentionally saved pre-existing drafts |
| Calendar keyboard | FRIApp.swift has Cmd+1 Today, Cmd+2 Month, Cmd+3 Year; many controls have no full focus contract | Use keyboard-contract.json and preview/keyboard.js. Keep native menus; guard open editor, focused text field and IME. Do not blindly intercept all NSEvents |
| Source pipeline | Native staged inbox and missing-field cards already exist | Retain staging, deduplication and fixed-time conflict holds; expose Add ready plans, not ambiguous Refresh. Use source/inbox and import tests as semantics |
| Desktop widgets | FRIDesktopWidgets.swift stores panel configuration and autosaved frames | Keyboard selection/move/resize/remove where supported; no stale saved widget after rapid create/delete. Restore existing panels and bounds. Do not port Explorer icon APIs |
| iOS Share | No share-extension target in project.yml | Add a native Share Extension for explicit text/image input, offline recognition, single-use App Group draft and review. Preserve original text privately; never put message contents into deep-link URLs |

Paths above are under `apple/FRI/` or `apple/Packages/FRICore/Sources/` unless specified. Native strengths such as Mac composer recognition and remembered websites must remain. Windows recognizes a narrower selected foreground window; that limitation is not a reason to remove Mac capabilities.

## Implementation sequence

1. **Record baseline.** Run the handoff checker and doctor, generate a receipt, compile existing targets and run Swift tests. Record failures before edits. Update all app/extension version values together only when the port is ready; suggested next native version is 0.8.2 with build number greater than every previously distributed native build (inspect rather than assume 8 is free).
2. **Resources and colors.** Merge the prepared catalog. Place the three TTFs plus OFL in a FRIDesign resource directory and add `.process("Resources")` to that package target. Register using Bundle.module and Core Text process scope before rendering in both hosts and widget processes. Do not install fonts systemwide. Use PostScript names from tokens. Retain a system fallback for registration failure and platform-controlled UI.
3. **Editor and first plan.** Use a local hour/minute/period model; Confirm alone mutates the parent draft. iOS may use native wheel controls. On macOS, SwiftUI `DatePickerStyle.wheel` is not available: build equivalent focusable scroll columns or a supported AppKit picker with the same explicit Confirm behavior. Every minute must remain selectable. Do not force the device timezone or change a selected date as a side effect. Retain appointment/recurrence/all-day semantics in FRICore. Remove redundant footer actions, not validation or meaningful error recovery.
4. **Keyboard and focus.** Implement command routing and FocusState first, then dates/search/tabs/feed. Stable record IDs drive focus restoration. A scheduled focus change must not override a later user action. When a month rerenders, retain the newly selected day. Configure single-character shortcuts; support command-modified shortcuts separately. Platform/browser-reserved combinations have visible menu alternatives.
5. **Widgets and Share.** Complete the AppKit panel flows and WidgetKit/AppIntent data path. Widget Done must be idempotent and committed before timeline reload. Larger families reveal more content; they do not enlarge all text. Add the iOS share target and an activation rule for supported text/URL/image items; bound inputs, cancel OCR and remove consumed drafts. Do not promise background chat monitoring on iOS.
6. **Regression.** Use acceptance.json as the portable checklist. Convert the interaction fixtures to native unit/UI tests with fixed clocks. Preserve current core/import/backup tests; update only tests that intentionally assert the superseded UI. Test true provider success, denial and offline paths with explicit user consent; do not invent live weather or Spotify playback.
7. **Distribution.** Build Release for both Mac variants and iOS. Sign only the variant being distributed with its real entitlements. Produce a fresh DMG in an output directory, validate it, then update the download pipeline. Archive/export iOS through Xcode; no iOS desktop installer exists.

## Platform behavior that must stay honest

- Only macOS main space uses behind-window material. Cards, buttons and dialogs are opaque. Keep the existing FRIWindowBackdrop fallback and Reduce Transparency behavior. iOS materials cannot reveal other apps behind Fri.
- WidgetKit owns placement, resizing and rendering. Interactive Done uses AppIntent; links open the app. Do not add a drag gesture to a WidgetKit snapshot or claim Finder icon displacement. AppKit widgets are separate windows and can support custom movement/resizing.
- No new Day model/provider, analytics, billing or account backend. Existing local features stay. Provider disclosure and consent are functional UI, not decorative subtext to remove.
- Physical iPhone access was previously excluded on the Mac workflow. Use Simulator first; do not treat this handoff as a new physical-device permission.

## Evidence expected

For each acceptance ID save commit, OS/Xcode, target, command or interaction, actual result, screenshot/video/XCResult and remaining limitation. Screenshots supplied here are Windows/browser reference states, not native proof. Keep real calendar contents, source cookies, keys, signing profiles and private logs out of commits.

References rechecked 27 November 2026: [wheel picker availability](https://developer.apple.com/documentation/swiftui/datepickerstyle/wheel), [bundled fonts and per-process registration](https://developer.apple.com/documentation/technologyoverviews/managing-the-fonts-for-your-app), [App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups), [interactive widgets](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities). Check installed SDK availability before implementation.
