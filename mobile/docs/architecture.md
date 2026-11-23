# Android ground truth

## Data and time

Room `fri.db` is the only source for calendars, events, presets, widget instances, pending pin requests and preferences. Native consumers and the React bridge use the same repository. Schema version 1 is exported; future changes require explicit migrations, not destructive fallback.

Timed events store UTC epoch milliseconds plus an IANA zone. A day uses that date's actual zoned midnight and the next date's midnight, including 23/25-hour daylight-saving days. Overlap is `event.start < day.end && event.end > day.start`. Cross-midnight events appear on every overlapping day. A non-existent spring-forward local time is rejected. A newly entered ambiguous repeated hour resolves to the first occurrence; edits that do not change the time preserve the stored instant.

All-day events store local `YYYY-MM-DD` start and exclusive end dates. The editor presents an inclusive final day and converts it on save. They do not shift when the device zone changes. Up next prioritizes an unfinished ongoing timed event, then the earliest future one, with stable ID tie-breaking. All-day items are a separate category.

## Widget lifecycle

Templates are `today_agenda` and `next_event`. Presets have UUIDs and versioned settings. Every confirmed launcher ID receives an independent settings snapshot; deleting or changing a preset does not alter existing widgets.

In-app configuration happens before `requestPinAppWidget`. A durable random token, unique callback URI and explicit one-shot PendingIntent correlate the callback. API 31+ uses a mutable PendingIntent so the launcher can supply the actual widget ID. The receiver validates action, token, request state and expected provider, then confirms idempotently in a Room transaction. It never fabricates an ID. The app says Requested until the launcher confirms. An old request without confirmation becomes Unconfirmed, not a false claim that the launcher reported cancellation.

The launcher's picker invokes the native Compose editor with the actual ID. RESULT_CANCELED is the default. A new install has a session-scoped provisional row; render failure/cancellation rolls it back. Only successful commit returns RESULT_OK. Reconfigure edits the existing ID without another pin. Drafts survive Activity recreation. Interrupted provisional sessions expire on reconciliation. Instance validation prevents writing settings to another provider's ID.

Glance receivers handle update, size changes, deletion and restored ID remapping. Reconciliation compares persisted rows with AppWidgetManager IDs and removes stale rows after a grace interval; installed but unconfigured widgets show setup, not invented settings. WorkManager schedules one unique approximate 15-minute job while widgets exist, plus coalesced invalidations after data/settings changes. Date/time/zone, reboot and package-replaced broadcasts request refresh. There is no JS refresh timer, exact alarm or foreground service. Android can defer work in battery-saving modes.

Glance uses SizeMode.Exact to make content decisions from the launcher's actual area. Font sizes remain stable; extra room reveals dates, actions, additional entries and progress. Within a live Glance composition, Room flows observe instance confirmation/settings and event changes. Calling update alone does not restart provideGlance, so a one-shot snapshot is insufficient. The reflectively created Done callback has an explicit Keep annotation for release shrinking.

Direct activity deep links are `fri://event?id=…`, `fri://?date=YYYY-MM-DD`, `fri://edit?date=…`, and the explicit native configuration Activity. They do not route clicks through broadcast trampolines. Removed events show an unavailable state. Completion is a native, idempotent action; widgets continue working with the React process absent.

## Privacy

No telemetry or remote calendar API. Room lives in Android app-private storage; Android backup is disabled. No external storage, contacts, system calendar, location or microphone permissions are requested. No claims of protection on rooted/compromised devices. Glance necessarily renders selected information to the user's launcher; per-widget Busy mode hides titles and places. Integration networking, if added later, must be opt-in and keep private event data out of provider requests.

## Sources consulted

- [Expo SDK 58](https://docs.expo.dev/versions/v58.0.0/) and [local native modules](https://docs.expo.dev/modules/get-started/)
- [Expo module API](https://docs.expo.dev/modules/module-api/) and [Router installation](https://docs.expo.dev/router/installation/)
- [Glance creation](https://developer.android.com/develop/ui/compose/glance/create-app-widget) and [configuration](https://developer.android.com/develop/ui/compose/glance/configuration)
- [Room releases](https://developer.android.com/jetpack/androidx/releases/room), [Glance releases](https://developer.android.com/jetpack/androidx/releases/glance), [WorkManager releases](https://developer.android.com/jetpack/androidx/releases/work)
- [CMake object path limit](https://cmake.org/cmake/help/latest/variable/CMAKE_OBJECT_PATH_MAX.html) and [Android native build configuration](https://developer.android.com/studio/projects/gradle-external-native-builds)
- [Glance sizing](https://developer.android.com/develop/ui/compose/glance/build-ui) and [live application state](https://developer.android.com/develop/ui/compose/glance/glance-app-widget)
