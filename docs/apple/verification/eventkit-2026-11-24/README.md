# EventKit runtime checks — 2026-11-24

The separate [CalendarFixture](../../../../apple/Tools/CalendarFixture/README.md) app creates a UUID-named local calendar in a dedicated Simulator. FRI reads it through the real EventKit API; FRI's own destination store is an isolated synthetic calendar. This does not validate production encryption, App Groups, Mac EventKit or physical devices.

- `ipad-imported.png`: the two selected events on the following day's calendar, including the all-day event explicitly assigned 16:00 and 30 minutes through the normal clarification flow.
- `ipad-source-check.png`: fixture verification after completing the imported timed appointment in FRI. The original four events retain their title set, locations and notes, the timed event's duration and one all-day event. This is a bounded source check, not a byte-for-byte database comparison.

The normal test also verifies three offered events within the seven-day window, excludes the event eight days away, skips one offered event, reopens the saved calendar and imports again without increasing the two-appointment count. Teardown removes only the helper-owned local calendar.

Initial iPad final normal-flow result: `test_sim_2026-11-23T23-12-39-068Z_pid22065_ce2862d0.xcresult`, one pass, zero failures/skips, 100.886 seconds of test execution. Screenshots above come from that run.

`iphone-permission-denied.png` shows the visible bottom feedback after actually tapping the system's Vietnamese **Từ chối** button. With the fresh `com.fri.qa.eventkitdenied2.ios` identity, the test then dismissed feedback, pasted a dated plan, supplied its duration and saved one appointment. Result: `test_sim_2026-11-23T23-26-29-835Z_pid22065_4a0f3045.xcresult`, one pass, zero failures/skips, 54.647 seconds of execution. This variant needs no source fixture and does not alter the normal FRI identity's permission.

Final iPad rerun after test permission handling and helper diagnostics/cleanup changes: `test_sim_2026-11-23T23-31-45-762Z_pid22065_bb2b4060.xcresult`, one pass, zero failures/skips, 140.639 seconds of test execution.

`iphone-imported.png` is from the final complete positive flow on a fresh iPhone 18 Pro Simulator, iOS 27.2. The helper and FRI both receive real full-access grants. Review/skip, clarification, relaunch, duplicate prevention, Done, source verification and cleanup all pass: `test_sim_2026-11-23T23-35-10-483Z_pid22065_da2ca760.xcresult`, one pass, zero failures/skips, 139.420 seconds. The older QA Simulator's helper remained denied after a Settings UI grant attempt; that permission-recovery case stays open and is not hidden by the fresh-grant pass.
