# Desktop update button

Fri's title bar shows a compact update pill when a newer release is available. Checking is automatic shortly after an installed app starts and every 30 minutes; **Help → Check for updates** uses the same state. Checking never downloads or installs a package.

On Windows, the pill moves through **Update v… → Downloading …% → Restart to update**. Downloading is explicit, progress is real, and the ready state is emitted only after `electron-updater` verifies the artifact. Restart asks for confirmation and waits for the renderer's pending saves and the encrypted native store. Dismissing restart leaves the update ready while the calendar remains usable. A failed check/download displays a retry action without exposing provider errors or filesystem paths.

macOS builds without Apple distribution signing show **Download v…** and open the fixed official release page. They do not claim automatic installation. The standalone HTML has no native updater. Development and automated test copies cannot install updates.

## Architecture

- `desktop/updates.cjs` owns state transitions, single-flight operations and the `electron-updater` adapter. Downgrades and prereleases are disabled; automatic download and install-on-quit are disabled.
- `desktop/main.cjs` wires `fri:updates` to the trusted main-window IPC validator and sends `fri:update-state`. The only actions are `status`, `check`, `download`, `install`, and `open-releases`. No path or URL is accepted from the renderer.
- `desktop/preload.cjs` exposes the narrow action and state subscription.
- `preview/chrome.js` renders the pill, flushes pending calendar writes before installation and subscribes to state changes. Its text is assigned through `textContent`.
- `preview/updates.css` places the control beside window controls using Fri's charcoal/marsala palette; keyboard focus, reduced motion and a phase-level screen-reader announcement are supported.

States are `idle`, `checking`, `current`, `available`, `downloading`, `ready`, `installing`, `manual`, `unavailable`, and `error`. A duplicate click joins the current operation. Applying an install requires the exact current downloaded version, never arbitrary renderer metadata. The existing app shutdown path closes widgets and waits for calendar writes.

## Reference study

The requested [WWW repository at `6a29944`](https://github.com/dakiemdarktharr/WWW/tree/6a2994438d1d22faeb2253cef5ce657326e4030f) separates its update control into `src/DesktopGate.tsx` (startup/30-minute checks and progress), `src/TitleBar.tsx` (conditional pill), and narrow preload IPC. Its main process obtains trusted release metadata, validates version/platform artifacts, streams bounded downloads while verifying SHA-256, and delegates replacement to OS-specific staged helpers. Its helper code includes recovery/rollback behavior and preserves profiles outside application directories. `src/UpdatePatches.tsx` is a release-history view, not the update engine.

Fri adopts the control/state/privilege separation. It retains its existing `electron-updater` and NSIS packaging rather than copying WWW's custom replacement helpers. Fri therefore does not claim WWW's staged rollback mechanism or unsigned macOS in-place updates. Failed downloads keep the current application; the published previous installer remains available for manual recovery.

## Verification

`node --test desktop/updates.test.cjs` exercises no-download checks, duplicate operations, progress, exact artifact version, failure/retry, unsupported platforms, confirmation, and save-before-install. `preview/updates.test.cjs` exercises title-bar interaction and progress with a mocked bridge. A real installed upgrade remains a separate release verification step; mocked transitions are not evidence of an actual installer replacement.
