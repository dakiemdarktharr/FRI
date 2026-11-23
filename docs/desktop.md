# Desktop ground truth — v0.3.0

Updated 2026-11-23. This section supersedes the archived v0.2 notes below.

## Implemented

- Encrypted local calendar through Electron safeStorage async API, atomic replacement, safe failure on unlock errors and migration from v0.2 localStorage. Writes merge changed fields so a widget completion survives an unrelated main-window edit. Failed writes stay queued for retry.
- Native rounded desktop widget with drag-to-create overlay, resize priorities, Done synchronization, persistence/reopen, options menu, tray and midnight rollover. Windows attaches to Explorer and repositions intersecting desktop icons. Auto arrange must be off. A coordinate recovery journal protects unchanged layouts; macOS uses a floating window.
- Local text/ICS/image review; Windows OCR via installed Windows.Media.Ocr; public HTTPS ICS/JSON-LD links with pinned public DNS, no redirects/cookies, 1 MB and timeout limits. Unsupported/failed sources do not discard successful drafts. Repeated source IDs are skipped; recurrence expansion and automatic source-update reconciliation remain in the older research workspace only.
- Simple free-slot planning and private local availability file comparison. Files contain free intervals only; live account calendar linking is not connected.
- Opt-in real Open-Meteo weather (manual region, periodic refresh, timestamp and cached/stale label), official Spotify Embed in a separate ephemeral session, Google Maps browser search and manual activity entry. Spotify full account playback and Google Places API widgets await configuration. Free Open-Meteo hosted API is noncommercial; change provider plan before commercial use.
- Private desktop notifications five minutes before an appointment while FRI runs. No cloud voice recognition; spoken playback selects a local system voice. Day remains a rule-based local helper, not a multimodal AI service.
- Existing native Acrylic/vibrancy and monochrome calendar UI, backup/restore, platform menus and updater retained.

## Verification checkpoints

13 native/core tests and 9 UI/import tests passed before final packaging; a separate network-boundary test also passes. Chromium and WebKit UI suites run locally. Actual Windows desktop exercise moved 9 icons and restored all recorded positions after removal. Actual Open-Meteo search/forecast returned Da Nang at 09:15 local, 27.1°C on the test request. Actual Spotify Embed loaded the Chill Hits playlist and exposed neither Node nor the FRI bridge; full account playback was not exercised. A synthetic image containing Team meeting, 2026-11-25 10:30, Room A was read correctly by the installed en-US Windows OCR engine. No personal user calendar was used for fixtures.

Installer upgrade, final CI artifacts and release publication are pending at this checkpoint. Final receipts will be recorded in release-verification.md. Security boundaries and limitations are in privacy.md; Apple follow-up is in apple-handoff.md.

## Archived v0.2 implementation notes


Updated 2026-11-22. The latest user request supersedes the beige/marsala preview: monochrome UI, no circled slogans, Search beside the logo, New with deadline/schedule choices, and a native desktop installer.

## Implemented

- Shared interface: `preview/` builds `FRI-liquid-glass.html`. The Electron app packages exactly that interface under a stable `app://fri/index.html` origin.
- Host: Electron 45.4.1, electron-builder 26.18.0, electron-updater 6.8.11. Electron preserves the approved HTML and ShaderGradient renderer while supplying native materials and window controls. Earlier Tauri notes are proposals.
- Windows 11 22H2+ uses system Acrylic. It reveals and blurs real wallpaper/windows behind FRI. macOS configures `under-window` vibrancy. HTML previews use a sample backdrop. Native Acrylic/vibrancy is not Apple's native Liquid Glass refraction renderer; external desktop pixels cannot be sampled by CSS displacement filters.
- Windows-style caption controls are on the right. The custom macOS traffic lights are on the left, monochrome by request; macOS also receives a native application menu.
- File/Edit/View/Help expose calendar backup/restore, appointment editing, search, views, sidebar toggle, shortcuts and updates. New offers a one-time due date/time or one scheduled appointment with duration. Recurrence is not implemented.
- Storage: Chromium localStorage in Electron's userData directory, separate from application installation. The key remains `fri-liquid-preview-v1`; the origin remains `app://fri`. Appearance migrates to monochrome once. Export/import moves calendar tasks between browser and desktop; preferences and drafts are not imported.
- Security: sandbox, context isolation, no renderer Node, CSP script hashes, restricted IPC sender and operation checks, denied remote navigation/network requests, allowlisted external destinations, no microphone permission in this preview. Backups validate identifiers and fields before confirmation.
- ShaderGradient remains 2.4.20 in the lockfile; upstream main reports 2.4.24. Only its colors change to grayscale. The source asset for Day is preserved; display uses a grayscale filter.

## Installation and updates

Windows NSIS uses stable appId `com.fri.calendar`, assisted per-user installation and no elevation. New installers replace application files at the registered install location. Calendar data stays in userData. Replacement occurs during installation, after the download is complete, so a failed download does not remove the working version. No unrelated folders or applications are removed.

Help → Check for updates uses GitHub releases on Windows. The user can download a newer build and restart/install. The installer metadata includes SHA-512 hashes and blockmaps. Initial packages are unsigned; a production signing identity is not configured. Signing verification is not overridden in code. macOS automatic installation remains unavailable until Apple signing/notarization is configured; its current update action opens Releases. A newer macOS app can replace the old one in Applications while preserving user Library data.

Builds produce a Windows x64 EXE plus macOS arm64/x64 DMG and ZIP packages on their respective hosts. macOS visual appearance still needs review on a physical Mac. Native OS widgets, reminders, accounts, live services and Day AI are future work. The desktop is a local calendar app around the approved UI, not completion of every V1 integration in the original brief.

Docker packages the browser interface behind non-root nginx on port 8080. It does not provide native desktop transparency. Run `docker compose up --build -d`, visit `http://127.0.0.1:8080`, and stop with `docker compose down`.

## Build and test commands

```powershell
npm ci --prefix preview
npm run build --prefix preview
npm ci --prefix tests
npm exec --prefix tests -- playwright install chromium webkit
npm ci --prefix desktop
node desktop/node_modules/electron/install.js
npm start --prefix desktop
npm run dist --prefix desktop

npm test --prefix preview
$env:FRI_BROWSER = 'webkit'
npm test --prefix preview
Remove-Item Env:FRI_BROWSER
npm run prepare:ui --prefix desktop
npm test --prefix desktop
npm audit --prefix desktop
```

Local Windows build 26200 verification: 8 preview scenarios pass in Chromium and 8 in WebKit; 2 additional desktop/monochrome scenarios pass, including isolation, invalid IPC, working window controls, deadline persistence across restart, menus, narrow layouts and unsafe-backup rejection. Native foreground inspection confirmed real applications blur through main space. Electron content screenshots omit DWM composition, so they cannot alone prove transparency. The locked desktop dependencies currently report zero audit vulnerabilities; minimatch is pinned to patched 11.0.1 through an override, with installer builds as compatibility verification.

Windows installer upgrade verified at 20:59 ICT on 2026-11-22: installed a 0.1.9 test build, added a deadline and changed text size, then installed 0.2.0 into the same isolated folder. Both installers exited 0; all 8 appointments and the text preference survived; an obsolete application file was removed; exactly one 0.2.0 entry remained in Windows uninstall registration. The test then uninstalled its own application and retained its test profile. Receipt: `D:/FRI-work/installer-check-2/receipt.json`.

Reproduce with `desktop/verify-upgrade.ps1 -Before <old.exe> -After <new.exe>`. It refuses to replace an existing FRI installation and confines its cleanup to the explicitly checked test path.

Live GitHub update also verified: an isolated installed 0.1.9 fixture checked the public 0.2.0 release through electron-updater, downloaded the release EXE, verified its SHA-512, then ran the real NSIS update path. The installed app reported 0.2.0 afterward with all 8 appointments and the larger-text preference intact. One initial connection reset left the old installation usable; retry succeeded. `desktop/verify-live-update.cjs` automates this opt-in test. Receipt: `D:/FRI-work/live-update-check/live-update-receipt.json`. Dialog responses and unattended installation are automated only by the test; the shipped app asks before download and restart/install. The initial 0.1.9 fixture was local, not a public release.

Release: [FRI 0.2.0](https://github.com/dakiemdarktharr/FRI/releases/tag/v0.2.0), built from `ad05924eea1436cb56954d28eb45a6910b830794`. All Windows and macOS assets plus the standalone HTML are uploaded. [Desktop/container run](https://github.com/dakiemdarktharr/FRI/actions/runs/45030877785) passed Windows and macOS native scenarios, both package builds and Docker HTTP checks. [Web run](https://github.com/dakiemdarktharr/FRI/actions/runs/45030877023) passed Chromium/WebKit preview and earlier V1 regressions. The macOS runner executed the arm64 app; x64 was packaged but was not executed on Intel hardware. Physical Mac appearance and signed/notarized macOS updates remain unverified.

Native backup export was additionally observed through Electron's `will-download` event, saved successfully as JSON and restored through the app's confirmation dialog. Playwright's page-level download event alone did not report that native download, so the native session receipt was used for verification.

## Primary references

- [Electron window materials](https://www.electronjs.org/docs/latest/api/base-window#winsetbackgroundmaterialmaterial-windows)
- [Electron security model](https://www.electronjs.org/docs/latest/tutorial/security)
- [NSIS packaging](https://www.electron.build/nsis/)
- [electron-builder updater source](https://github.com/electron-userland/electron-builder/tree/master/packages/electron-updater)
- [ShaderGradient source](https://github.com/ruucm/shadergradient)
