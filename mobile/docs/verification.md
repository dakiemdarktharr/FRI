# Android verification · 0.1.0 local alpha

Date: 2026-11-23, Asia/Saigon. Windows host; one Pixel 4 / Android 15 API 35 x86_64 emulator, 2 GB guest RAM, WHPX. The launcher was the actual Pixel launcher, driven through Android input/UI Automator and inspected with screenshots. No web preview was used as widget evidence.

## Artifacts

| APK | Bytes | SHA-256 |
|---|---:|---|
| FRI-0.1.0-android-arm64.apk | 31,590,615 | `7ccb909fbb638ea62cba404495e5d8bac4ab1ace7c46df0a0971e2c02555753a` |
| FRI-0.1.0-android-x86_64.apk | 32,166,756 | `84830a94e0a2ac567b78ee4fc0eff59e72191de99332ef773bfcfa1ac3e94189` |

Local output: `dist/android/` at repository root. Both are optimized release builds with bundled JavaScript, R8 and resource shrinking, signed with the local generated debug key. ARM64 compiled; execution was verified on x86_64 only. They are not store-signed or published Android releases.

## Observed checks

- TypeScript and ESLint pass. Expo Doctor: 20/20. npm audit: zero known vulnerabilities at verification time.
- Seven JUnit tests pass: 23/25-hour DST days, half-open overlap and cross-midnight, all-day local exclusive dates in three zones, ongoing/next selection, nonexistent and repeated local hours, calendar filters/settings serialization.
- Two Android instrumentation tests pass against in-memory Room: preset/instance independence, provisional rollback, completion preserving event fields, durable pin state, and live observation of instance confirmation/event completion.
- Release APK installed and launched without Metro or login. First run had no seeded events; Personal and Work calendars existed.
- Created Personal and Work events through the app. APK replacement preserved them. Edited a title and verified the saved detail; deleted that event and observed its launcher widget become empty. Created an all-day plan from the widget + action and observed All day on the launcher.
- Warm create deep link and cold event deep link opened the correct form/detail, including start, end and IANA zone. No React or Metro server was required for native rendering and completion.
- In-app pin: Save preset alone did not create an instance. Canceling the system confirmation left zero instances; accepting a retry created a real launcher ID. The app showed Requested before confirmation.
- Launcher picker listed both Fri providers. Native configuration opened directly. Back canceled a new configuration without removing the existing widget. Saving an Up next widget created a real second-provider instance.
- Two Today Agenda instances retained different Personal/Work filters. Reconfiguring one to dark/Busy preserved its ID and masked its title; the other retained its configuration.
- Resize changed actual widget bounds from 570×610 px to 972×937 px. Task text remained 16 sp; additional date/progress content appeared. Widget layout uses actual launcher size, not a stretched fixed template.
- Launcher drag moved Up next from the upper left to the lower right. Drag to the launcher's Remove target removed only that instance; the other two remained.
- 150% system font size retained readable event/action content; lower-priority content was omitted. The emulator's original 100% setting was restored.
- Native Done in the optimized APK immediately changed Up next to No upcoming events. Room flow updates also propagated all-day creation and event deletion while the widget session was active.
- App dark appearance and 24-hour preferences saved through Settings.

Device screenshots and raw diagnostic logs remain in local test-results/; no user desktop images or build-host identifiers are published as fixtures.

- Rebooted the emulator: both placed widgets retained their filters/privacy, the all-day event remained available through a cold widget tap, and app dark/24-hour preferences persisted. No Metro process was needed.

## Defects found and fixed during device testing

1. The initial discrete responsive sizes selected a layout too small for a 3×2 Pixel allocation, leaving excess blank space. SizeMode.Exact now uses the actual area.
2. R8 removed the no-argument DoneCallback constructor used by Glance reflection. A targeted Keep annotation preserves the callback; release optimization remains enabled.
3. A one-shot read before provideContent kept a newly configured widget at Set up during a live Glance session. Instance and event Room flows now drive the composition. A native observer regression test and actual launcher confirmation/completion were used to verify the change.

## Remaining coverage and boundaries

- Physical ARM64 phones, other launchers, API 24/25 desugaring at runtime, tablets/foldables and maximum vendor font scaling are not verified.
- Synthetic duplicate/late pin callbacks, OS backup ID remapping, process death during the exact provisional commit window, device timezone changes and Doze delays still need broader lifecycle testing. Unit date/DST tests are separate from these device scenarios.
- Periodic WorkManager refresh is approximate (15 minutes or later under system policy), not an exact alarm. Force stop is different from normal backgrounding/process reclamation.
- No account, payment, cloud sync, Android music/maps/weather integration or desktop glass parity is claimed. This is the local Android calendar/widget MVP described in README, not the Windows feature set ported in full.
- Desktop installers and website deployment are verified separately in docs/release-verification-0.5.0.md.
