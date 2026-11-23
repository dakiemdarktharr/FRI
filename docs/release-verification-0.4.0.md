# FRI 0.4.0 verification

Date: 2026-11-23 (Asia/Saigon). Windows 11 build 26200, x64.

## Changes

- Guarded native Direct3D desktop refraction from @hicccc77/electron-liquid-glass 0.3.0; source reviewed at 0684fe7fd74855e4b13bd3e8d7b6db40f91e132a. Native GPU pipeline, not Apple's compositor. Unsupported OS/hardware retains material/solid fallback. Panels suspend when hidden, minimized or disabled.
- Widgets have explicit pointer/keyboard move and resize, durable geometry, real rounded native clipping on Explorer and opaque monochrome surfaces to avoid child-window alpha artefacts. Main workspace still uses glass. Multi-display free-cell planning avoids gaps; actual multi-DPI/Explorer variants need wider hardware coverage.
- Isolated Leaflet/OpenStreetMap map, Spotify player reuse/disconnect, forecast/disconnect race protection. Calendar data never crosses provider bridges.
- Reused sidebar rendering context for unchanged settings; demand rendering for paused gradient; offscreen web ocean/demo/footer work suspended. No absolute performance percentage claimed.
- Website: concise product/benefit/conflict/import answers, actual desktop widget walkthrough, mobile layouts, prismatic/glossy Premium card at 50,000 VND/month. Purchase remains unavailable.
- Nine Apple handoff guides document parity, Xcode/WidgetKit, shared data, native materials, integrations, signing and acceptance. Day work is deferred.

## Observed checks

Installer 0.3.0→0.4.0 installed/upgraded with exit 0, preserved an explicitly seeded deadline and large-text setting, removed an obsolete application file and left exactly one 0.4.0 uninstall registration. Isolated installation removed afterwards. Final rebuild receipt: D:/FRI-work/upgrade-040-final-autoplay/receipt.json, 14:03:59 +07:00. The initial test harness incorrectly assumed seven demo events in a fresh 0.3 profile; corrected it to compare a captured before/after task snapshot.

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

## Real desktop interaction

At the user's request, the normal packaged EXE was opened without test mode on the real Windows desktop. Physical pointer creation and two drags displaced 10 icons, then five additional icons. No icon cells intersected the final widget rectangle. Removing the widget restored all 32 original coordinates exactly. The [aggregate receipt](verification/0.4.0/desktop-icon-reflow.json) contains no filenames or screenshots; private desktop captures remain local. Explorer Auto arrange was off.

The website widget video now autoplays muted and loops when visible; leaving the viewport pauses decoding. Reduced-motion and the accessible animation toggle still work. Chromium confirmed playback time advanced without invoking Play.

Linux WebKit CI exposed an expiring Undo notification under slow rendering. Actionable Undo now remains available until another notification or action replaces it; informational notifications still dismiss.

## Final build receipts

Tested source: `ad31d45cd89c48c4deef4047400ef1bbee59f243`. Subsequent release-receipt edits change documentation only.

- [Desktop CI](https://github.com/dakiemdarktharr/FRI/actions/runs/45128402869): Windows, macOS and Docker jobs passed. Mac DMG/ZIP assets are unsigned Electron development previews, not native Xcode/WidgetKit builds.
- [Web CI](https://github.com/dakiemdarktharr/FRI/actions/runs/45128399242): Chromium and Linux WebKit passed, including autoplay without invoking Play, six viewport widths, FAQ and pricing. This resolves the Linux playback check left pending by the Windows WebKit codec limitation.
- Final local Windows EXE: 14 packaged tests passed after rebuild; the final installer upgrade receipt above was rerun against the same artifact.
- `FRI-0.4.0-win-x64.exe`: 125,483,150 bytes; SHA-256 `22ec9f5cd2fa61402d3d360e0a986ba2a6f83fe0ef7d9072c11e4d9790bed43e`.
- Download alone does not remove an installed application. Running the new installer replaces old application files while retaining user data.

## Published artifacts and website

[Release v0.4.0](https://github.com/dakiemdarktharr/FRI/releases/tag/v0.4.0) was published at 2026-11-23 07:12:18 UTC. All 14 payload SHA-256 digests matched GitHub's uploaded-asset digests; SHA256SUMS.txt is included. Windows and both Mac architecture download URLs returned HTTP 200. Mac files come from the successful CI build above; the Windows EXE is the locally verified final installer.

[Production website](https://fri-acne-a6cd.vercel.app) is deployed from `d2c74e3d4ff0b73adb999ffe45e6752764904f84`, deployment `dpl_2v537DAQ7ocQTGf4AAfAb2XhZbSv`, state READY. Its widget video response is HTTP 200 with video/mp4 content type; the visible video has autoplay, muted, loop and playsinline, without playback controls. Chromium production checks passed the intro, demo, mobile layouts, pricing, FAQ, autoplay and automated accessibility checks.

Windows WebKit also encountered a stalled media/load lifecycle on the HTTPS deployment, beyond its known codec limitation. Navigation checks now wait for DOMContentLoaded followed by the actual UI assertion, rather than all media. The passing [dedicated production workflow](https://github.com/dakiemdarktharr/FRI/actions/runs/45130536131) verifies the public URL in Linux Chromium/WebKit; this does not certify physical iPhone Safari. Publication metadata and artifact digests are in [publication.json](verification/0.4.0/publication.json).

Final production verification passed in Chromium and Linux WebKit, including autoplay without invoking Play. An initial 320 px WebKit measurement ran before route/viewport layout settled; the assertion now waits for a fitting layout (maximum three seconds) and emits overflow diagnostics on failure. All six widths then passed without changing production CSS or app code. Physical iPhone Safari remains outside this Windows verification.
