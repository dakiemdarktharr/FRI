# Architecture, data and migration

Create apple/FRI.xcodeproj with FRIMac, FRIiOS, FRIMacWidgets and FRIiOSWidgets. Create apple/Packages/FRICore containing Models, Validation, Scheduling, Import, Storage, WidgetSnapshot and ServiceContracts plus unit tests. FRIDesign contains shared typography, spacing, mosaic and controls. Platform adapters own Keychain, Vision, EventKit, notifications and file access. UI never sends calendar content to an account service.

Use native SwiftUI on iOS and Mac; Electron does not target iOS. Keep Electron Mac as comparison until parity is proven. If temporarily retaining Electron with a native Mac extension, use a signed native helper to access the App Group, not a guessed filesystem path or secrets in JS.

## Existing wire contract

Read desktop/store.cjs validate/merge. Current state.version=1; encrypted envelope is {state, revision}. Tasks contain string id, title, date YYYY-MM-DD, time HH:mm, integer duration minutes, category, location, notes, done and optional kind. Deadline means kind=deadline and duration=0; missing kind is a legacy schedule. Limits: 10,000 tasks, title 160, category 35, location 200, notes 2000 characters; JSON at most 8 MiB. Unique IDs use ASCII letters/digits/underscore/hyphen, at most 100. Dates must exist; intervals cannot cross local midnight. Reject duplicate IDs, invalid dates and prototype keys. Preserve compatible unknown settings on round-trip.

tabs, active, widgets, collections, finished, drafts and settings belong to state. Windows settings.desktopWidgets pixel bounds are platform-specific: retain in exports but do not interpret as WidgetKit coordinates. Settings also include weather, mapsLocation/mapsRegion, spotifyUrl, activity, reminders and appearance. Never transfer calendar.v1.encrypted across operating systems: Windows DPAPI and Apple keys are not interchangeable.

v1 task times are local wall-clock values without a time zone. Preserve this during migration; appending Z would change the meaning. A future zoned v2 needs an explicit migration with original zone, instant and DST ambiguity policy. Free-time exchange already uses instants: port the existing parser/schema, not a second invented format. Generate golden fixtures from desktop/planning.test.cjs and the existing domain tests.

## Durable app ↔ widget writes

Use FileManager.containerURL(forSecurityApplicationGroupIdentifier:) and an encryption key in a shared Keychain group. Encrypt calendar/snapshots with authenticated encryption such as CryptoKit AES.GCM, a versioned envelope and random nonces. An actor only serializes one process: use an interprocess lock or transactional database for app/extension writers. Never hold the lock during network waits.

Under lock, read current revision, apply field-level changes against the sender's base, validate, encrypt, write temporary file and atomically replace. Deleted tasks must not resurrect. complete(taskID) sets Done=true, never toggles; duplicate taps are harmless. Notify UI/request timeline reload only after durable commit. Back up before migration and fail closed on key/decryption errors; do not overwrite with an empty calendar.

Widget snapshots contain minimal upcoming data, protected with the same key/container policy. No plaintext task titles in UserDefaults, logs or committed screenshots. Mark sensitive fields privacySensitive and redact while locked. Choose key accessibility deliberately: after-first-unlock device-only supports background access after unlock; when-unlocked is stricter and can require a locked placeholder. Test on-device rather than weakening protection to avoid a placeholder.

[App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups) and [Keychain sharing](https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps) are distinct capabilities; verify both on app/extension. Keys remain non-synchronizing until an explicit encrypted-sync design exists.

## Migration acceptance

Export a synthetic Windows calendar, import on Mac/iPhone, export again and compare semantic fields/settings. JSON backup is intentionally readable: warn at export, use user-chosen destination, never upload. Test corrupt ciphertext, interrupted write, migration rollback, simultaneous edit/Done, deleted IDs, time-zone change, midnight and DST skip/repeat.
