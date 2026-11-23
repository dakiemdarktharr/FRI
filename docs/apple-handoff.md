# macOS and iOS development handoff

The supplied design research is preserved byte-for-byte as [fri_design_guidebook.pdf](fri_design_guidebook.pdf), SHA-256 `680ae6cab00d0f553f76142647a7b27568204c6e1c3835f792482c8d175d2ab3`. Renaming does not change its original authorship or the status of the underlying Apple references.

## Current implementation

- Approved app palette: monochrome. Marketing website: white + marsala `#955251`, with a halftone ocean.
- Main app shell: Electron 45.4.1, native Acrylic on Windows 11 22H2+, under-window vibrancy on macOS. These are real native blur/transparency, not Apple's native Liquid Glass compositor. Browser HTML uses a simulated backdrop.
- Keep information architecture: day first, tabs for dates, month/year views, duration-sized mosaic, completion ring, New deadline/schedule, File/Edit/View/Help and a simple sidebar.
- Shared data is local and encrypted. Reuse task fixtures and free-time interval contracts; no calendar-content backend is present.
- Widget priority: current task and Done → weekday → date → progress → opt-in service information → upcoming tasks. Small sizes omit lower priorities. See desktop/widget.html container queries.
- Windows Explorer attachment/icon repositioning and Windows OCR are platform-specific. Mac widgets currently use a normal floating Electron window; Finder icon reflow and WidgetKit are not implemented.

## Apple release work

Build on macOS with Node 24, run preview and desktop tests, then `npm run dist --prefix desktop`. Configure Apple Developer signing and notarization before distribution. Verify Keychain persistence across two signed versions, under-window vibrancy on varied wallpapers, reduced transparency, VoiceOver, multiple displays and Spaces. Unsigned artifacts from CI are development builds, not a notarized Mac release.

For native iOS/macOS surfaces, map controls to SwiftUI materials and platform navigation instead of porting CSS refraction. WidgetKit needs a native extension, App Group snapshot store, timeline/reload policy, App Intents for Done, deep links and protected storage. Use local Vision OCR on Apple devices. Calendar reminders need platform authorization and cancellation/reconciliation after edits. No iOS target, entitlement, installer or device test is claimed by this Windows release.

Spotify account playback, Google Places/Routes data, account/plan infrastructure and encrypted cross-device availability linking require separate configured integrations. The current keyless paths are an isolated Spotify Embed, Google Maps URL search, Open-Meteo forecast and explicit local free-time file comparison. Open-Meteo's free hosted API is noncommercial; configure an appropriate plan/provider before commercial service use.
