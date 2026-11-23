# FRI 0.3.0 — Windows desktop release

FRI now keeps a local encrypted calendar and puts your current task directly on the Windows desktop. Premium is **Coming soon**. No account or payment is required.

## What is included

- Day-first monochrome calendar, native Windows Acrylic/macOS vibrancy, date tabs, duration-sized task cards, search, settings and completion ring.
- New schedule/deadline, batch entry, missing-information cards, overlap review, edit/delete/undo and backup/restore.
- Draw an area to create a rounded desktop widget. Move/resize it, complete tasks, see progress and configured weather/music/maps/activity controls. Windows desktop icons move out of the widget area when Auto arrange is off; unchanged positions are restored on removal.
- Encrypted local persistence and migration from v0.2. Image OCR on Windows, text/ICS/public-link review, a basic free-slot planner and private free-time file comparison.
- Opt-in Open-Meteo forecast, isolated Spotify Embed, Google Maps browser search, manual activity and private desktop reminders while FRI runs.
- Revised website: XP opening, moving halftone surf, full scrolling demo, scramble title, continuous footer gallery and separate Pricing.

## Downloads and upgrading

Use **FRI-0.3.0-win-x64.exe** on Windows. Install over the previous version: old application files are replaced while calendar data and settings remain. Downloading an update alone never deletes the working installation. The upgrade from 0.2.0 was tested with eight saved appointments, appearance settings, obsolete-file cleanup and one uninstall entry.

Windows builds are unsigned. The macOS DMG/ZIP files are **development builds**, not notarized releases. macOS widget behavior is a floating window; Finder icon reflow, Windows OCR and iOS are not provided there. The supplied design PDF and Apple handoff are in docs/.

## Verified and remaining

Native/core, UI, browser, accessibility and packaging checks are recorded in docs/release-verification.md. The surf loop was inspected across 276 consecutive frames; curtains, scramble and demo also received visual review. Native transparency and Windows desktop-icon restoration were checked on Windows build 26200.

There is no calendar-content server or telemetry. Provider requests require explicit actions and send the city/search/content identifier and network metadata necessary for that service; see docs/privacy.md. Backups are readable files chosen by the user.

No billing, account service, cloud/multimodal Day AI, OAuth playback, Google Places/Routes API, automatic shared-calendar link, recurrence expansion or overnight/nested travel planner is claimed by this release. Spotify full playback depends on Spotify; weather is a provider forecast, not a guarantee. Signing, native Apple widgets and physical Mac/iOS validation remain follow-up work.
