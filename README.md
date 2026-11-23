# FRI

A local-first calendar with a native glass workspace and desktop widgets. **Premium: 50,000 VND/month, coming soon. No payments or account signup are enabled.**

- **Website:** https://fri-acne-a6cd.vercel.app — XP-style opening, halftone surf, continuous app demo and Pricing.
- **Installers:** [GitHub Releases](https://github.com/dakiemdarktharr/FRI/releases).
- **Review files:** [website HTML](FRI-website.html) and [app HTML](FRI-liquid-glass.html), both self-contained.
- **Design handoff:** [fri_design_guidebook.pdf](docs/fri_design_guidebook.pdf) and [Apple platform handoff](docs/apple-handoff.md).

## Use FRI

Start with **New → Schedule** or **One-time deadline**. Name your plan, add details, choose **Add another**, then **Done**. FRI asks for missing information one card at a time and checks overlaps before saving. Complete each task to fill the day ring. Dates open in separate tabs; Calendar shows month and year views. Search, edit, bulk delete, undo, backup and restore are available from the sidebar and menus.

**File → Create FRI widget on desktop** opens a drawing overlay. Drag out an area, then release. Move the widget by its header, resize from its bottom-right grip (or use arrow keys on the focused header/grip), and complete the current task directly. Its content adapts to the available space. Windows Explorer icons move out of its area when Auto arrange icons is off, and unchanged positions are restored when the last widget closes. On macOS this is currently a floating window; Finder icon reflow and WidgetKit are not implemented.

**File → Import plans** accepts text, ICS, images and public HTTPS calendar links. Windows OCR reads images locally with installed OCR languages. Review source evidence and dates before confirming. **Find time for a task** finds a contiguous free slot; **Find time together** compares explicitly shared free-time files without event details.

Weather fetches a real Open-Meteo forecast for a chosen city. Spotify opens an isolated official Embed player; account playback depends on Spotify. Maps opens an interactive OpenStreetMap view for a city you choose. Health is a manual step entry. These optional actions disclose the provider receiving the request. [Privacy boundaries](docs/privacy.md).

The Windows x64 workspace uses a guarded Direct3D desktop-refraction layer from @hicccc77/electron-liquid-glass, with OS-material/solid fallbacks. This samples the actual desktop locally on the GPU; it is not Apple's compositor. macOS currently uses under-window vibrancy; the native Apple implementation is specified in the handoff. Fri uses ivory, charcoal and marsala (#955251). Only the main workspace is translucent; appointment cards, buttons and dialogs are opaque. Desktop widgets keep fixed type sizes and reveal additional content as they grow, with + in empty integration slots.

## Android

The [Android local alpha](mobile/README.md) starts with an Expo/React Native app, Kotlin/Room storage, native Compose configuration, and two Glance home-screen widgets. Read its [verification status](mobile/docs/verification.md) before relying on a feature. Android does not yet include all desktop integrations; APKs are local test builds, not a store release.

## Native Apple development

The `apple/FRI.xcodeproj` project contains SwiftUI macOS and iOS apps with embedded WidgetKit extensions. Select `FRIMac` or `FRIiOS` in Xcode. Native widgets adapt their content to the system size and Dynamic Type; the app includes size previews and native placement instructions. This is separate from the Electron download described above. Signed installation and shared App Group/Keychain verification still require the owning Apple Developer team. [Widget build and verification](docs/apple/verification/WIDGETS-2026-11-23.md).

## Develop and verify

Use Node.js 24. Run commands from the repository root:

```powershell
npm ci --prefix preview
npm ci --prefix tests
npm exec --prefix tests -- playwright install chromium webkit
npm ci --prefix desktop
node desktop/node_modules/electron/install.js
npm run build --prefix preview
npm start --prefix desktop

npm run prepare:ui --prefix desktop
npm test --prefix desktop
npm test --prefix preview
npm test --prefix tests
node website/build.mjs
node website/verify-v2.cjs
node website/verify-responsive.cjs
npm run dist --prefix desktop
```

The website builder writes a standalone HTML with embedded video, plus a smaller served page and video asset in website/public. Website tests generate screenshots and 276 frame captures under test-results. See [web verification](docs/web-verification-2026-11-23.md) and [desktop ground truth](docs/desktop.md) and [release verification](docs/release-verification.md).

Docker serves the browser version, without OS glass or native widgets:

```powershell
docker compose up --build -d
# http://127.0.0.1:8080
docker compose down
```

## Release boundaries

v0.5 is a Windows-first, keyless release. Calendar data is encrypted locally with OS-provided keys. No calendar-content server or telemetry exists. Windows installers replace old application files and retain user data; update installation happens after download succeeds. Builds are unsigned until signing certificates are supplied. Mac CI artifacts are development builds requiring signing, notarization and physical-device review before a supported Mac release.

Premium entitlement, account signup, OAuth/Spotify Web Playback SDK, Google Places/Routes APIs, automatic shared-calendar linking, cloud/multimodal Day AI and an iOS app are not shipped. Day provides local planning shortcuts and on-device spoken playback when a system voice is available. Recurrence expansion, overnight schedules and nested travel/context planning are not exposed in the new desktop interface. The earlier research workspace and its richer domain tests remain in index.html; the current desktop reuses its ICS/JSON-LD parser, not its entire separate data model.

[Apple build and parity guide](docs/apple/00-START-HERE.md) · [0.5 verification](docs/release-verification-0.5.0.md) · [Current release scope](docs/release-plan.md) · [Technology](docs/technology.md) · [Ocean asset license](website/assets/NOTICE.md)
