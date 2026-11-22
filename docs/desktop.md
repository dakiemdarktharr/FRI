# Desktop ground truth

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

Reproduce with `desktop/verify-upgrade.ps1 -Before <old.exe> -After <new.exe>`. It refuses to replace an existing FRI installation and confines its cleanup to the explicitly checked test path. This verifies actual NSIS replacement and data retention; it is separate from an end-to-end live download/update test against two published production releases.

## Primary references

- [Electron window materials](https://www.electronjs.org/docs/latest/api/base-window#winsetbackgroundmaterialmaterial-windows)
- [Electron security model](https://www.electronjs.org/docs/latest/tutorial/security)
- [NSIS packaging](https://www.electron.build/nsis/)
- [electron-builder updater source](https://github.com/electron-userland/electron-builder/tree/master/packages/electron-updater)
- [ShaderGradient source](https://github.com/ruucm/shadergradient)
