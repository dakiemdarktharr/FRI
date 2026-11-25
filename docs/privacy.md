# FRI privacy boundaries

FRI 0.7.0 stores appointments, drafts, settings and widget layout on the device. There is no FRI calendar server, analytics SDK, advertising SDK, account database or billing collection in this release. Premium is advertised at 50,000 VND/month and remains unavailable for purchase.

The desktop writes an atomic encrypted calendar file in Electron userData. Encryption uses Electron safeStorage's asynchronous OS key provider (Windows DPAPI / macOS Keychain). A failed unlock never resets the saved calendar. Existing v0.2 localStorage is migrated only after an encrypted write succeeds, then its active key is removed. This does not promise forensic erasure of older disk sectors or browser database remnants.

The main renderer has no Node access, runs in a sandbox with context isolation, hashed scripts and denied HTTP/HTTPS requests. Narrow IPC methods validate their sender and data. Widgets use a separate restricted bridge. Calendar titles and notes are never sent with weather, maps or Spotify requests.

## Meeting suggestions in selected chat windows

The calendar assistant starts after the user selects a Zalo or Messenger window. It requests window video only. macOS uses ScreenCaptureKit and Vision while that window is frontmost. Windows and Linux use a separate local capture session and bundled Vietnamese Tesseract data. Recognition examines changing pixels in the conversation area. On macOS, the selected Zalo window also has a separate recognition region at the bottom for the unsent composer. An invitation there can show a dismissible suggestion while the user types. No keyboard listener is used. Unrelated or sensitive text visible in that area can therefore be processed in memory. The assistant keeps raw chat text and images out of its logs, calendar database and network requests.

The first observation of sent messages establishes a baseline. A new visible confirmation can produce a proposed title, date, time and place. The user reviews a suggestion before it becomes a calendar entry. Device preferences remember source identifiers and title hashes where the operating system allows reuse. The user can stop capture in FRI or revoke system permission. Wayland capture remains bound to the selected portal stream for that session.

## Explicit external actions

| Action | What leaves the device | Destination |
|---|---|---|
| Website visit | Standard HTTP metadata/IP | Vercel; no app calendar data |
| Download / check for updates | Standard request metadata, update version request | GitHub release infrastructure |
| Read public calendar link | Requested URL and IP, no cookies or calendar upload | The selected HTTPS site; each redirect is revalidated and public DNS addresses are pinned for the Node request |
| Sign into a calendar source | Account login and cookies supplied to that provider | User-selected site in an isolated browser; locally encrypted cookies persist until disconnected or expired; browser DNS uses Chromium |
| Read with AI | Selected image/page/text, local date/time zone and API authentication | OpenAI Responses API; no existing calendar, cookies or passwords in the source; no FRI server |
| Choose weather city | City search, then selected coordinates and IP | Open-Meteo; forecast refresh every 30 minutes while FRI runs; Disconnect stops refresh |
| Explore maps | Manual city search, selected map area/tiles and IP; no automatic location tracking | Open-Meteo city lookup and OpenStreetMap tiles in an isolated map window |
| Open Spotify player | Selected content URL, playback/account activity managed by Spotify | Spotify in an isolated, nonpersistent browser session, with no FRI bridge |
| Export backup / free time | A local file, shared only if the user sends it | User-selected filesystem location |
| Enable Day OpenAI ranking (opt-in) | Bounded suggestion summaries with relevant appointment titles, dates/times, card IDs and urgency; no notes, locations, raw sources or images | OpenAI Responses API, GPT-6 Luna at max reasoning, `store: false`; requests occur automatically after relevant changes while enabled |

Windows image import runs through the installed Windows OCR engine. A temporary image is created in the user's app-data directory and removed after processing; the source image is not uploaded by local OCR. Enabling Read with AI uploads the chosen source to OpenAI instead. Only reviewed text is added to appointments. Image recognition depends on installed OCR languages. Reading the day aloud uses an on-device English voice only. Cloud voice recognition is not enabled. For Day, conflict/deadline detection is local; OpenAI ranking is off by default and requires explicit provider-specific consent in Day. Turning it off prevents future requests and ignores late results, but cannot retract content already sent. `store: false` is not a claim of zero provider retention; provider account policies still apply.

The separate Day API key is read only by the desktop main process from an ignored local environment file or process environment, and is excluded from release bundles. It is not returned through IPC. The local key file is plaintext, separate from the encrypted calendar store. Day sends no notifications through new OS channels, never writes to source calendars, and applies a move only after a click and a fresh transaction check. See [Day configuration and limits](day-ai.md).

Calendar JSON backups contain readable private details and should be stored carefully. Free-time exports contain time intervals only, never event titles, notes or locations; intervals can still reveal a person's availability pattern. The user chooses whether to share the file.

Windows desktop collision handling reads icon coordinates, not file contents. A local coordinate-only recovery journal restores an unchanged layout after a crash; it avoids restoring if the user or Explorer changed the layout. No desktop screenshot or icon name is uploaded.

OS encryption protects a copied file and other operating-system accounts. On Windows it does not isolate secrets from malicious software already running as the same signed-in user. An unlocked device, user-exported backups, screenshots, provider accounts and compromised operating systems remain outside that protection. FRI does not claim absolute privacy against those threats. Unsigned macOS builds can prompt for Keychain access again after an update; stable code signing is needed before a supported Mac release.

Provider references: [Electron safeStorage](https://www.electronjs.org/docs/latest/api/safe-storage), [Spotify Embeds](https://developer.spotify.com/documentation/embeds), [OpenStreetMap tile policy](https://operations.osmfoundation.org/policies/tiles/), [Open-Meteo terms and pricing](https://open-meteo.com/en/pricing).

## Native refraction and service isolation (0.4)

On supported Windows x64 hardware, desktop/glass.cjs uses a native Direct3D desktop-duplication/refraction layer. Desktop pixels remain in GPU memory; FRI does not persist them, expose them to renderer JavaScript or upload them. The separate lens panel excludes itself from captures to avoid recursion, so screen recordings may not include the visible lens. Disabling glass or hiding/minimizing the window suspends the panel. Unsupported systems retain an OS material or solid fallback; this is not Apple's native compositor.

The map renderer has its own restricted preload and session, no calendar bridge, no geolocation permission and only OSM tile network access. Normal HTTP tile cache is stored locally in its isolated session; Disconnect Maps closes the map and clears that cache. Spotify uses a separate ephemeral session; Disconnect closes playback and clears session storage. Disconnect Weather invalidates an in-flight forecast so a late response cannot reconnect it.

## Import consent and saved sessions (0.6.1)

Read with AI is a visible per-import choice and requires a locally configured OpenAI key. The native process stores it encrypted, removes it from the editable config, and never returns it to renderer JavaScript. Model responses use `store: false`; this does not override the API provider’s account-specific retention rules. Extracted records/drafts and short evidence snippets become part of the encrypted local calendar. Raw images and captured pages are not persisted by the production import flow. Browser HTTP cache/history and provider cookies can exist locally until Disconnect.

A source partition is separate for each requested origin, with no preload/Node/FRI bridge and denied device permissions/downloads. Cookies are saved atomically with OS-backed encryption. Sessions are not guaranteed permanent: server expiry, revocation, MFA or embedded-browser restrictions still apply. Disconnect works without contacting the provider and deletes the saved vault and browser storage. The OS profile encryption metadata must accompany ciphertext in a full-profile backup. See [import guide](smart-import.md).

## Prepared sources (0.7)

The inbox, source labels/links, essential answers and bounded extraction-result cache are part of the encrypted local state. PDF/DOCX text is decoded in a worker on the device. Files and folder selections are read only when chosen; no folder watcher is installed. Reading a source does not change appointments. Refresh performs deterministic local validation and planning; it does not call OpenAI. Browser-only preview storage is localStorage and is not OS encrypted.
