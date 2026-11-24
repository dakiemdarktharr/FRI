# FRI

A local-first calendar with a native glass workspace and desktop widgets. **Premium: 50,000 VND/month, coming soon. No payments or account signup are enabled.**

- **Website:** https://fri-acne-a6cd.vercel.app — XP-style opening, halftone surf, continuous app demo and Pricing.
- **Installers:** [GitHub Releases](https://github.com/dakiemdarktharr/FRI/releases).
- **Review files:** [website HTML](FRI-website.html) and [app HTML](FRI-liquid-glass.html), both self-contained.
- **Design handoff:** [fri_design_guidebook.pdf](docs/fri_design_guidebook.pdf) and [Apple platform handoff](docs/apple-handoff.md).

## Use FRI

Start with **New → Schedule** or **One-time deadline**. Name your plan, add details, choose **Add another**, then **Done**. FRI asks for missing information one card at a time and checks overlaps before saving. Complete each task to fill the day ring. The default feed scrolls through Today, Tomorrow and following days. One selector switches to week, month or year; date tabs stay available. Search, edit, bulk delete, undo, backup and restore are available from the sidebar and menus.

**File → Create FRI widget on desktop** opens a drawing overlay. Drag out an area, then release. Move the widget by its header, resize from its bottom-right grip (or use arrow keys on the focused header/grip), and complete the current task directly. Its content adapts to the available space. Windows Explorer icons move out of its area when Auto arrange icons is off, and unchanged positions are restored when the last widget closes. On macOS this is currently a floating window; Finder icon reflow and WidgetKit are not implemented.

**Sources → Add a source** accepts links, images, folders and files (ICS, JSON, CSV, text, HTML, PDF with text, DOCX). Structured readers and Windows OCR run locally; optional OpenAI handles complex sources. Day asks only for required details, then stores a prepared batch. Add more sources and press **Refresh** in the menu bar: valid plans are added, past/duplicate records are skipped, and fixed-time conflicts stay in Sources for review. Reading alone never changes the calendar. [Import flow and boundaries](docs/smart-import.md).

Weather fetches a real Open-Meteo forecast for a chosen city. Spotify opens an isolated official Embed player; account playback depends on Spotify. Maps opens an interactive OpenStreetMap view for a city you choose. Health is a manual step entry. These optional actions disclose the provider receiving the request. [Privacy boundaries](docs/privacy.md).

The Windows x64 workspace uses a guarded Direct3D desktop-refraction layer from @hicccc77/electron-liquid-glass, with OS-material/solid fallbacks. This samples the actual desktop locally on the GPU; it is not Apple's compositor. macOS currently uses under-window vibrancy; the native Apple implementation is specified in the handoff. Fri uses **Cloud / Ink / Teal**, with light and dark themes. Only the main workspace is translucent; appointment cards, buttons and dialogs are opaque. Desktop widgets keep fixed type sizes and reveal additional content as they grow, with + in empty integration slots.

## Day and calendar insights

Day’s circular wave opens source intake. **File → Calendar insights** retains the existing local planner, which automatically checks Fri's existing calendar for conflicts and approaching deadlines. It proposes moving only flexible work; the user clicks to apply. There is no chat prompt requirement. Optional OpenAI **GPT-6 Luna, max reasoning** ranks the validated suggestions through the desktop main process.

Enter `OPENAI_API_KEY` in the ignored `desktop/.env.day`, run `node start-day.cjs`, then enable OpenAI inside Day → **Cách Day hoạt động**. The HTML preview supports local suggestions. See [Day setup, architecture and limitations](docs/day-ai.md). No hosted inference service is deployed by this branch.

## Android

The [Android local alpha](mobile/README.md) starts with an Expo/React Native app, Kotlin/Room storage, native Compose configuration, and two Glance home-screen widgets. Read its [verification status](mobile/docs/verification.md) before relying on a feature. Android does not yet include all desktop integrations; APKs are local test builds, not a store release.

The accepted design and source workflow are recorded in [Cloud feed ground truth](docs/cloud-feed-redesign.md).

## Native Apple development

Open `apple/FRI.xcodeproj` in Xcode. `FRIMac` is the standalone SwiftUI/AppKit Mac app, with encrypted local storage, a login-Keychain key and desktop widget windows. Use **File → New Desktop Widget**; the top bar moves it, the bottom-right grip resizes it, and its menu provides sizes, placement, date and keep-on-top controls. Widget windows restore with the app and share its calendar directly. They require FRI to remain running.

`FRIMacWidgetKit` and `FRIiOS` embed the system WidgetKit extensions and use App Group/Keychain sharing; those configurations require the owning developer team. The standalone Mac configuration never silently falls back from a failed shared store. Transfer calendars between the standalone and App Group configurations using a JSON backup. These native apps are separate from the Electron download described above.

The native 0.7.0 development build opens in the Cloud feed and includes week, month and year views. Add files, text or links under **Sources**, review missing details and use **Refresh** to apply prepared plans. The shared Windows planner reserves fixed appointments first and keeps unresolved conflicts for review. See the [production acceptance ledger](docs/apple/verification/PRODUCTION-READINESS.md) and [earlier WidgetKit build evidence](docs/apple/verification/WIDGETS-2026-11-23.md).


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

For the macOS “damaged” download failure and the required signed release pipeline, see [macOS download repair](docs/macos-download-repair.md). On macOS, `npm run dist --prefix desktop` now requires Developer ID signing and notarization. Use `npm run dist:mac:development --prefix desktop` only for local development artifacts.

v0.7.0 is a Windows-first release. Core calendar, ICS import and local planning work without API keys; optional source extraction uses the user’s OpenAI key. Calendar data is encrypted locally with OS-provided keys. No calendar-content server or telemetry exists. Windows installers replace old application files and retain user data; update installation happens after download succeeds. Builds are unsigned until signing certificates are supplied. Mac CI artifacts are development builds requiring signing, notarization and physical-device review before a supported Mac release.

Premium entitlement, account signup, OAuth/Spotify Web Playback SDK, Google Places/Routes APIs, automatic shared-calendar linking, multimodal Day and an iOS app are not shipped. Day has local suggestions plus separately opted-in OpenAI ranking; import consent does not enable Day. ICS import expands bounded recurrences and splits overnight events. Nested travel/context planning remains in the earlier research workspace in index.html and is not exposed in this desktop UI.

[Apple build and parity guide](docs/apple/00-START-HERE.md) · [0.7.0 redesign verification](docs/release-verification-0.7.0.md) · [0.6.1 import verification](docs/release-verification-0.6.1.md) · [0.6 verification](docs/release-verification-0.6.0.md) · [Current release scope](docs/release-plan.md) · [Technology](docs/technology.md) · [Ocean asset license](website/assets/NOTICE.md)
