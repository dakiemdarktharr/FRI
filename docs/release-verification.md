# FRI 0.3.0 release verification

Verified on 23 November 2026. This records observed checks and separates platform limits from shipped behavior.

## Local Windows checks

- 13 native/core/planning/widget tests passed. Native GUI suites now run sequentially to avoid two macOS app instances competing for windows.
- Packaged EXE: native menus, isolation, deadline creation, search, maximize/minimize, persistent encrypted restart, widget drawing, Done sync, responsive priorities, configured service controls and widget removal passed.
- Packaged Windows OCR read the synthetic `Team meeting / 2026-11-25 10:30 / Room A` image with the installed en-US engine. Public HTTPS source fetch succeeded; renderer HTTP/HTTPS remained blocked.
- Actual Windows build 26200: a widget displaced nine desktop icons and removal restored every recorded position. The restore comparison was empty after accounting for Explorer's grid snapping. Auto arrange must be off. This was one physical desktop configuration; other DPI/multi-display/Explorer versions need device coverage.
- Actual system screenshot over a separate checkerboard window confirmed main-space Acrylic reveals and blurs the window behind. A window-only capture omits the OS backdrop and is not sufficient evidence of opacity.
- Actual Open-Meteo returned Da Nang forecast data; Spotify Embed displayed the real Chill Hits playlist in a separate session with neither Node nor the FRI bridge. Full Spotify account playback and actual operating-system notification delivery were not tested. Google Maps uses its official browser search URL, not an embedded Places API.
- Installer upgrade **0.2.0 -> 0.3.0**: both installers returned 0; eight saved appointments and large-text settings survived; an obsolete application file was removed; exactly one uninstall entry remained. The temporary test installation was then uninstalled. The user's data directory was not used for this test.
- Released Windows installer SHA-256: `8c2de0e055e0b7b1bb82c82a19f5ab6d208100a9daeb7ef44c5826cfe6e925bd`. Its SHA-512 matches `latest.yml`. It was built from native runtime commit c62ce32; subsequent desktop changes only adjust test readiness and serialization.

## Web checks

- Legacy domain suite: 14 tests. Legacy browser suite: 19 per engine. Current app UI/import suite: 9 per engine. Website revision 2: 16 checks across Chromium and WebKit; Chromium axe audit returned zero violations.
- All 276 consecutive surf frames (9.2 seconds, 30 fps) reviewed in six contact sheets. Additional curtain, scramble and demo states reviewed. See [web verification](web-verification-2026-11-23.md).
- Linux download tests account for the release chooser on unsupported platforms; Windows gets the direct EXE. Frame review seeks have a bounded fallback for media engines that never deliver seeked. Actual Apple Safari playback remains unverified; Windows WebKit displays the supplied poster when H.264 decoding is unavailable.

## CI and distribution

Final desktop/container CI passed: https://github.com/dakiemdarktharr/FRI/actions/runs/45101706693 (b847e21). Final web CI passed: https://github.com/dakiemdarktharr/FRI/actions/runs/45101652605 (fec31b3). The only desktop change between those commits is a test readiness fix. All 15 release assets were compared against local SHA-256 hashes before publication; both update manifests match the installer/archive SHA-512 values. Release: https://github.com/dakiemdarktharr/FRI/releases/tag/v0.3.0 . Windows installer is unsigned. macOS CI builds are unsigned/not notarized development artifacts, not a supported physical-device Mac release. Docker checks the non-root browser container; it does not provide native OS materials/widgets.

## Reproduce

```powershell
npm ci --prefix tests
npm exec --prefix tests -- playwright install chromium webkit
npm ci --prefix preview
npm ci --prefix desktop
node desktop/node_modules/electron/install.js
npm run build --prefix preview
npm run prepare:ui --prefix desktop
npm test --prefix desktop
node --test desktop/network.test.cjs
npm test --prefix preview
npm test --prefix tests
node website/build.mjs
node website/verify-v2.cjs
npm run dist --prefix desktop

# Test the packaged Windows app; clear the variable afterwards.
$env:FRI_TEST_EXE='D:/FRI/dist/win-unpacked/FRI.exe'
node --test --test-concurrency=1 desktop/desktop.test.cjs desktop/widget.test.cjs
Remove-Item Env:FRI_TEST_EXE

# Isolated NSIS upgrade test; refuses an existing registered FRI installation.
./desktop/verify-upgrade.ps1 -Before D:/FRI/dist/FRI-0.2.0-win-x64.exe -After D:/FRI/dist/FRI-0.3.0-win-x64.exe -BeforeVersion 0.2.0 -AfterVersion 0.3.0 -TestRoot D:/FRI-work/upgrade-030-review
```

Generated evidence lives in ignored test-results/, desktop/test-results/ and the chosen upgrade test directory. Test calendars contain synthetic data only. [Privacy](privacy.md) and [Apple handoff](apple-handoff.md) describe unimplemented features and limits; no blanket claim that every original V1 idea has shipped is made.
