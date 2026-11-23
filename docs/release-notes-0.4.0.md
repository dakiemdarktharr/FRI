# FRI 0.4.0 — desktop widgets and native glass

FRI keeps appointments, deadlines and daily progress on your device, with the next task available directly on your desktop.

## Changes

- Native Windows desktop refraction, blur and rounded glass edges, with reduced-transparency/unsupported-system fallbacks. Rendering suspends when the window is hidden or minimized.
- Rounded desktop widgets with pointer and keyboard movement/resizing, persistent geometry, Done, and removal. Content adapts to widget size. With Explorer Auto arrange off, icons move out of the widget's area and unchanged positions return after the last widget closes.
- Interactive OpenStreetMap city maps, an isolated official Spotify Embed player, and real Open-Meteo forecasts. Reopening Spotify reuses its player; disconnect controls clear connection state. No calendar content is shared with these providers.
- A concise mobile website covering benefits, conflicts, imports and widgets. The real desktop walkthrough autoplays muted, loops when visible and pauses offscreen. Premium has a prismatic/glossy card: **50,000 VND/month, coming soon**. No payment is enabled.
- Reduced unnecessary sidebar rendering and offscreen website work. Actionable Undo remains available until replaced, including on slow devices.
- Nine detailed [Apple handoff guides](https://github.com/dakiemdarktharr/FRI/blob/main/docs/apple/00-START-HERE.md) cover Xcode, SwiftUI, WidgetKit, shared protected storage, parity, signing, installers and verification. New Day work is deferred.

## Install and update

Windows: download **FRI-0.4.0-win-x64.exe** and install over the older version. The installer replaces application files while retaining calendar data and settings. Downloading alone does not remove the working installation.

Windows builds are unsigned. macOS DMG/ZIP assets are unsigned development previews, not notarized native Apple releases. Native Xcode/WidgetKit and iOS builds must be completed and tested on a Mac using the handoff.

## Verification and limits

Packaged Windows native tests: 14 passed. Real desktop pointer testing moved 10 icons, then five more; no icon cells remained covered, and removing the widget restored all 32 positions. The 0.3.0 → 0.4.0 installer test preserved a seeded deadline/settings and left one uninstall entry. Details, CI receipts and evidence are in [release verification](https://github.com/dakiemdarktharr/FRI/blob/main/docs/release-verification-0.4.0.md).

Spotify playback availability remains subject to Spotify/account restrictions. Weather uses the free provider configuration; commercial use requires appropriate provider terms before enabling payments. Hardware-specific glass behavior, multiple GPU/display configurations and physical iPhone Safari still require broader device coverage. No billing, automatic account-linked calendars or cloud Day agent is included.
