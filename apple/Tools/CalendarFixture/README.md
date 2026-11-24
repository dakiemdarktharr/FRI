# EventKit Simulator fixture

A separate, Simulator-only SwiftUI app for exercising FRI's actual EventKit permission and import UI. It is not linked into the shipping app. Compilation deliberately fails for physical devices and macOS.

Use a dedicated QA Simulator with no personal calendars or signed-in calendar accounts: FRI's production import reads all calendars granted by the system. The helper itself requires a local EventKit source and only creates, verifies and removes its own UUID-named local calendar.

## Run

1. Generate this project with XcodeGen: `xcodegen generate --spec apple/Tools/CalendarFixture/project.yml`.
2. Build scheme `FRICalendarFixture` for the chosen iOS Simulator and install its app on that Simulator.
3. Run `FRIiOSUITests/FRIWorkflowTests/testAppleCalendarImportWithRealEventKitStore` in the main FRI project with test-runner environment `FRI_EVENTKIT_TESTS=1`.
4. For the permission-denied variant, also set `FRI_EVENTKIT_DENY=1` and build the main project under a fresh `FRI_BUNDLE_PREFIX` (for example `com.fri.qa.eventkitdenied`). A real system denial prompt is required; the test fails if that prompt does not appear. Do not reset permissions for the normal FRI identity.

The test creates four real EventKit events: tomorrow's timed, all-day and skipped events, plus an event eight days away. It selects two, asks the user-facing review flow to supply the all-day event's time and duration, checks persistence and duplicate prevention, and completes a local FRI appointment. The helper verifies that the source still has the four expected titles, locations and notes, the timed event's duration and one all-day event. This is a bounded source check, not a byte-for-byte EventKit database comparison.

The denied variant checks visible failure feedback and a successful pasted-text fallback; it requires no fixture app or calendar. The normal variant removes its fixture calendar in XCTest teardown, including on assertion failure.

## Cleanup after an interrupted runner

The `EventKit-fixture-ID` test attachment contains the run UUID. Launch the helper with that exact value as `FRI_CALENDAR_FIXTURE_ID`, then tap **Remove calendar**. Removal requires the identifier previously stored by this helper, the exact UUID-based title and a local source. It never searches for or deletes unrelated calendars. Preserve the helper's app data until cleanup succeeds; uninstalling it first would lose the ownership identifier.

Neither the helper nor its test accesses the host Mac's calendar, modifies the system clock or installs onto an iPhone. Actual device, Mac EventKit and distribution verification remain separate gates.
