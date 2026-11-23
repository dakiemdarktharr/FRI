# FRI 0.4.0 verification

Date: 2026-11-23 (Asia/Saigon). Windows 11 build 26200, x64. Publication receipts are added after release.

## Changes

- Guarded native Direct3D desktop refraction from @hicccc77/electron-liquid-glass 0.3.0; source reviewed at 0684fe7fd74855e4b13bd3e8d7b6db40f91e132a. Native GPU pipeline, not Apple's compositor. Unsupported OS/hardware retains material/solid fallback. Panels suspend when hidden, minimized or disabled.
- Widgets have explicit pointer/keyboard move and resize, durable geometry, real rounded native clipping on Explorer and opaque monochrome surfaces to avoid child-window alpha artefacts. Main workspace still uses glass. Multi-display free-cell planning avoids gaps; actual multi-DPI/Explorer variants need wider hardware coverage.
- Isolated Leaflet/OpenStreetMap map, Spotify player reuse/disconnect, forecast/disconnect race protection. Calendar data never crosses provider bridges.
- Reused sidebar rendering context for unchanged settings; demand rendering for paused gradient; offscreen web ocean/demo/footer work suspended. No absolute performance percentage claimed.
- Website: concise product/benefit/conflict/import answers, actual desktop widget walkthrough, mobile layouts, prismatic/glossy Premium card at 50,000 VND/month. Purchase remains unavailable.
- Nine Apple handoff guides document parity, Xcode/WidgetKit, shared data, native materials, integrations, signing and acceptance. Day work is deferred.

## Observed checks

Installer 0.3.0→0.4.0 installed/upgraded with exit 0, preserved an explicitly seeded deadline and large-text setting, removed an obsolete application file and left exactly one 0.4.0 uninstall registration. Isolated installation removed afterwards. Receipt: D:/FRI-work/upgrade-040-verified/receipt.json. The initial test harness incorrectly assumed seven demo events in a fresh 0.3 profile; corrected it to compare a captured before/after task snapshot.

Actual pointer input on packaged Windows app: create rectangle; move from (399,220) to (649,150); resize 362×431→432×481; Done reveals next task; menu removes widget. Captured with synthetic tasks/plain demo desktop in website/assets/widget-walkthrough.mp4. Recording uses capture-friendly OS material; native lens is separately verified because its own capture exclusion omits that panel from screen recordings.

Live Open-Meteo response for Da Nang returned 28.3°C with provider timestamp/timezone; 15 visible OSM tiles loaded; Spotify official Chill Hits Embed loaded. Reopening same Spotify link reused its window; all three disconnects cleared saved connection state. A successful Embed load is not proof of unrestricted account playback.

Native lens diagnostic: 97 renders, unchanged after one second disabled. A separate synthetic grid window verified actual desktop blur and curved edge displacement. See [source](verification/0.4.0/glass-source.png) and [refraction](verification/0.4.0/glass-refraction.png). Capture exclusion was disabled only in that diagnostic, after the first valid image, to make the lens visible in its screenshot. Production keeps exclusion enabled. An initial single-shot library probe captured a black first frame; the continuous production pipeline subsequently returned valid content (mean luminance about 210/255). These observations are not a benchmark or universal GPU/multiple-display certification.

Packaged EXE: 14/14 native tests passed, including encrypted restart, task completion, widget create/move/resize/remove, small-size content priorities and restricted IPC. One source-network isolation test, nine UI/intake tests and 14 domain tests passed. Production dependency audit found zero reported vulnerabilities. Live provider checks were repeated on the packaged EXE: 15 map tiles, current forecast, isolated Spotify Embed, window reuse and disconnects. The Spotify Play button was exercised; unrestricted account/audio playback is not certified by this test.

Website: 320, 375, 390, 768, 1024 and 1440 px layouts and FAQ/pricing interactions passed in Chromium and WebKit. Chromium playback and automated WCAG A/AA checks passed with zero reported violations. This Windows WebKit build stayed at media readyState 0 for both MP4 and WebM; its local playback check is explicitly skipped and remains mandatory on Linux/macOS CI. [Playwright documents platform-dependent codecs](https://playwright.dev/docs/browsers#webkit); physical iPhone Safari validation remains a Mac handoff item.

The ocean review captured 276 consecutive frames at 30 fps without seek timeouts. All 501 frames of the actual widget walkthrough were inspected as eight consecutive contact sheets; create, move, resize, Done and removal remain visible. The video uses synthetic data and a purpose-made desktop, with VP9 WebM and H.264 MP4 variants.

The installer upgrade receipt is [committed here](verification/0.4.0/installer-upgrade.json). No user calendar or desktop screenshot is included in these public fixtures.

## Reproduce

```powershell
npm ci --prefix preview
npm ci --prefix tests
npm ci --prefix desktop
node desktop/node_modules/electron/install.js
npm exec --prefix tests -- playwright install chromium webkit
npm run build --prefix preview
npm run prepare:ui --prefix desktop
npm test --prefix desktop
node --test desktop/network.test.cjs
npm test --prefix preview
node website/build.mjs
node website/verify-v2.cjs
node website/verify-responsive.cjs
npm run dist --prefix desktop
```

Installer is unsigned because no code-signing certificate is configured. No native Xcode targets, notarized Apple release, billing backend or live cross-account calendar linking are claimed. Weather's free host requires an appropriate commercial arrangement before paid service use. Provider availability and Spotify account playback are external constraints.
