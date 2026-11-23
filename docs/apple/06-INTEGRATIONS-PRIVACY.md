# Integrations, imports and privacy

Calendar operation is local. No appointment content/screenshots/recordings go to FRI servers. Optional providers see requests and IP; disclose before connection. Do not claim zero network when services are enabled. Task fields never enter provider URLs, logs or account/plan records.

| Service | Windows behavior | Apple equivalent |
|---|---|---|
| Weather | Manual city, Open-Meteo, timestamp/stale cache/disconnect | URLSession/shared cache; no location permission for manual city. WeatherKit alternative needs capability/account/attribution. |
| Spotify | Pasted public link, isolated official Embed, reuse/disconnect | Isolated app WKWebView or approved deep link; widget opens app. Full playback depends on provider/account. |
| Maps | Isolated Leaflet/OSM, chosen city, attribution/disconnect | App MapKit preferred, snapshot/Link in widget; OSM alternative follows tile policy. Generic places are not verified trending POIs. |
| Activity | Manual daily steps | Same manual feature; HealthKit requires separate implementation/consent. |
| Imports | ICS/CSV/text/files/local OCR/reviewed HTTPS/JSON | FileImporter/PDFKit/Vision; optional EventKit read connection. No implied live Google/CalDAV sync. |

Open-Meteo free hosting is noncommercial. Configure an appropriate commercial endpoint/provider before paid service use. Premium50,000 VND/month is advertised but billing/entitlements are absent; purchase remains unavailable. [Terms](https://open-meteo.com/en/terms).

OSM tiles are best-effort: HTTPS, visible attribution, identifiable User-Agent, HTTP caching, actively viewed tiles only; no bulk/offline downloads. [Policy](https://operations.osmfoundation.org/policies/tiles/). Spotify Embed needs no secret for a public link but is not authenticated Web API/SDK control; don't infer unrestricted playback from preview evidence. [Embeds](https://developer.spotify.com/documentation/embeds).

Import transaction: decode → proposals → unsupported/missing/conflict review → question cards → explicit commit. Never fabricate times. Preserve source identity for duplicate handling. Keep file/response limits and private-network URL defenses. Port folded ICS/all-day/zones/CSV quoting/unsupported recurrence fixtures.

Vision VNRecognizeTextRequest runs locally. PDFKit extracts text first; scanned pages rasterize for OCR. Balance security-scoped access, persist bookmarks only when ongoing access requested. [Vision](https://developer.apple.com/documentation/vision/recognizing-text-in-images).

EventKit import requests full access only on Connect Calendar, with NSCalendarsFullAccessUsageDescription and Mac calendar entitlement. Denial leaves file import usable. EventKitUI creation does not grant import access. [Access levels](https://developer.apple.com/documentation/eventkit/accessing-the-event-store), [migration](https://developer.apple.com/documentation/technotes/tn3152-migrating-to-the-latest-calendar-access-levels).

PrivacyInfo.xcprivacy/App Store disclosures match actual APIs/SDKs; no analytics by default. Test disconnect during in-flight forecast, revoked permissions, offline maps, Spotify external navigation, invalid deep links/imports and synthetic secrets in logs. Future account service stores identity/plan only; sync needs an explicit encrypted design.
