# Native service cards — 2026-11-24

Checkpoint before the user-requested goal pause. Production readiness remains IN PROGRESS.

## Changes

Aligned empty service-card headings, copy, colors, padding and corner radius with the shipping `window.FRI_SERVICE_CARD` implementation in `preview/native.js`, rather than the sample cards in `preview/app.js`. Cards follow persisted widget order, including Up next. Each card has a remove action that preserves service settings and an action opening only its service section. The general Services entry still opens all sections. Music quick link opens Spotify directly.

Controls retain native 44-point minimum targets (the desktop remove control is smaller). Connected weather retains the native cached summary, range and timestamp with Open-Meteo attribution. This is not a claim of complete pixel or connected-state parity.

## Completed checks

All Simulator tests used isolated synthetic stores; no physical iPhone was accessed. Result bundles are under the local MobileBuildMCP `MOMO-c7c317bd7fec/result-bundles` directory.

| Check | Result | Result bundle |
|---|---|---|
| iPhone order, routing, removal, settings retention and relaunch | PASS, 1 test | `test_sim_2026-11-24T00-32-00-374Z_pid22065_28e60529.xcresult` |
| iPad same workflow plus larger-text sidebar/Up next regression | PASS, 2 tests | `test_sim_2026-11-24T00-34-42-612Z_pid22065_65663ad2.xcresult` |
| iPhone entire Maps card inside landscape viewport; open/remove hittable | PASS, 1 test | `test_sim_2026-11-24T01-11-05-366Z_pid61849_b3372b34.xcresult` |
| iPad entire Maps card inside landscape viewport; open/remove hittable | PASS, 1 test | `test_sim_2026-11-24T01-12-25-772Z_pid61849_86741ab9.xcresult` |
| macOS Debug compilation | PASS, no warning/error diagnostics | `/tmp/fri-service-cards-mac-final.log` |

The workflow also verifies 44-point controls, editing 4,321 steps, removing/re-adding Health without losing its saved value, and service-specific versus general settings navigation. The final two full-screen landscape captures were visually reviewed: the complete Maps card and controls are visible. Scrolling is expected for the complete rail; these captures do not certify every screen or Dynamic Type category.

Desktop reference was rendered from the repository's `FRI-liquid-glass.html` in isolated headless Chromium with empty tasks and the five service widgets seeded into preview localStorage. No product DOM/CSS was altered. `desktop-reference.json` records computed styles; the included activity capture is the desktop reference, not native output.

## Limits and handoff

No fresh macOS UI runtime result is claimed for this checkpoint. Earlier Computer Use window lookup failures, incomplete runtime matrices, complete visual parity and signed WidgetKit/shared-store/distribution gates remain documented in `../PRODUCTION-READINESS.md`. Successful builds and these Simulator checks do not make the app production ready. User requested pushing the current work and then pausing the automatic goal; do not interpret this checkpoint as goal completion.
