# FRI privacy boundaries

FRI 0.3 stores appointments, drafts, settings and widget layout on the device. There is no FRI calendar server, analytics SDK, advertising SDK, account database or billing collection in this release. Premium is coming soon.

The desktop writes an atomic encrypted calendar file in Electron userData. Encryption uses Electron safeStorage's asynchronous OS key provider (Windows DPAPI / macOS Keychain). A failed unlock never resets the saved calendar. Existing v0.2 localStorage is migrated only after an encrypted write succeeds, then its active key is removed. This does not promise forensic erasure of older disk sectors or browser database remnants.

The main renderer has no Node access, runs in a sandbox with context isolation, hashed scripts and denied HTTP/HTTPS requests. Narrow IPC methods validate their sender and data. Widgets use a separate restricted bridge. Calendar titles and notes are never sent with weather, maps or Spotify requests.

## Explicit external actions

| Action | What leaves the device | Destination |
|---|---|---|
| Website visit | Standard HTTP metadata/IP | Vercel; no app calendar data |
| Download / check for updates | Standard request metadata, update version request | GitHub release infrastructure |
| Read public calendar link | Requested URL and IP, no cookies or calendar upload | The user-selected public HTTPS site; public DNS addresses pinned for the request; redirects/private addresses blocked |
| Choose weather city | City search, then selected coordinates and IP | Open-Meteo; forecast refresh every 30 minutes while FRI runs; Disconnect stops refresh |
| Explore maps | The region/search and browser metadata | Google Maps in the user's browser |
| Open Spotify player | Selected content URL, playback/account activity managed by Spotify | Spotify in an isolated, nonpersistent browser session, with no FRI bridge |
| Export backup / free time | A local file, shared only if the user sends it | User-selected filesystem location |

Windows OCR runs through the installed Windows OCR engine. A temporary image is created in the user's app-data directory and removed after processing; the source image is never uploaded. Only reviewed text is added to appointments. Image recognition depends on installed OCR languages. Reading the day aloud uses an on-device English voice only. Cloud voice recognition and Day AI are not enabled.

Calendar JSON backups contain readable private details and should be stored carefully. Free-time exports contain time intervals only, never event titles, notes or locations; intervals can still reveal a person's availability pattern. The user chooses whether to share the file.

Windows desktop collision handling reads icon coordinates, not file contents. A local coordinate-only recovery journal restores an unchanged layout after a crash; it avoids restoring if the user or Explorer changed the layout. No desktop screenshot or icon name is uploaded.

OS encryption protects a copied file and other operating-system accounts. On Windows it does not isolate secrets from malicious software already running as the same signed-in user. An unlocked device, user-exported backups, screenshots, provider accounts and compromised operating systems remain outside that protection. FRI does not claim absolute privacy against those threats. Unsigned macOS builds can prompt for Keychain access again after an update; stable code signing is needed before a supported Mac release.

Provider references: [Electron safeStorage](https://www.electronjs.org/docs/latest/api/safe-storage), [Spotify Embeds](https://developer.spotify.com/documentation/embeds), [Google Maps URLs](https://developers.google.com/maps/documentation/urls/get-started), [Open-Meteo terms and pricing](https://open-meteo.com/en/pricing).
