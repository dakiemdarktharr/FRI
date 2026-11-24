# Manual activity validation and Services labels

Original XCTest screenshots, reviewed at full screen size. Synthetic UUID-scoped stores; iOS/iPadOS 27.2 Simulator only.

- [iPad invalid input](ipad-invalid.png): persistent Steps today label, rejected 100001 and complete inline error/action.
- [iPhone larger text](iphone-larger-text-invalid.png): the same error wraps and Save remains reachable after scrolling. This is the app Larger text preference, not every system Dynamic Type size.
- [iPhone live weather](iphone-weather.png): persistent City label and the selected Paris, Texas forecast. Network values are observations at test time.

`testManualActivityRejectsInvalidInputAndPersists` saves 4321; rejects abc, empty, -1, 1.5 and 100001; reopens to verify 4321 is retained; saves 0 and 100000; relaunches; clears activity and verifies removal. The test reveals the error by scrolling, so this does not establish immediate no-scroll visibility or VoiceOver speech.

Before-fix runtime failure: `test_sim_2026-11-23T23-54-08-957Z_pid22065_56d471ce.xcresult`. The numeric TextField reverted invalid text to 4 after editing a previously saved 4321, without an error. An earlier test assumption incorrectly expected comma grouping instead of the Simulator locale's dot; that diagnostic was corrected before reproducing the bug.

After-fix iPad: `test_sim_2026-11-23T23-56-35-720Z_pid22065_892b8d5b.xcresult`, one pass, zero failures/skips, 94.136 seconds body.
After-fix iPhone: `test_sim_2026-11-23T23-59-49-400Z_pid22065_dad38c41.xcresult`, two passes, zero failures/skips: larger-text activity 105.443 seconds, live weather 46.811 seconds. Environment: `FRI_SERVICE_LARGE_TEXT=1`, `FRI_WEATHER_NETWORK_TEST=1`.

Core parser: `swift test --package-path apple/Packages/FRICore --filter ManualActivityTests`, two passes. Complete-input validation covers locale grouping, Arabic digits, bounds, malformed grouping, nonnumeric suffixes and integer overflow. Mac Debug build passed without warning/error diagnostics, `/tmp/fri-activity-mac-final.log`; new Mac onscreen behavior remains unverified.
