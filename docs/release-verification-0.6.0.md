# FRI 0.6.0 — Day and update controls

Release candidate checked on 23 November 2026. Publication and remote CI status are recorded below when completed.

## Changes

- Proactive Day receives the existing calendar, detects conflicts, proposes user-confirmed moves for flexible work, and reminds deadlines within 24 hours. Optional OpenAI GPT-6 Luna at max reasoning ranks validated suggestions. [Architecture and configuration](day-ai.md).
- A Codex-style title-bar update pill follows the requested WWW reference's separation of UI state and privileged updater work. Windows downloads on click and restarts only after confirmation and saved calendar writes. macOS uses the official release-download page. [Updater architecture](updater.md).
- Windows widget geometry no longer grows during movement at fractional DPI. The native regression covers repeated no-op/move operations at observed 125% scaling, exact resizing, encryption and persistence; pure geometry cases cover 100/125/150/175/200%.
- Container builds now include the shared Day planner without including the desktop credential directory. Preview tests use the selected Chromium/WebKit engine.

## Local evidence

- Desktop suite: 62/62 passed.
- Preview: 17/17 Chromium and 17/17 WebKit passed.
- Network-boundary test passed; production dependency audit found zero vulnerabilities.
- Website interaction checks before link update: 9 Chromium checks passed, axe returned no violations.
- Windows NSIS built successfully. ASAR inspection confirmed version 0.6.0, all Day/update modules, no credential files or project tests, and exact runtime/source matches.
- The actual unpacked Windows executable passed all 5 native/calendar/Day/widget checks, including Day apply and restart persistence.
- Day's OpenAI connection was tested with one synthetic request: structured output valid, model `gpt-6-luna`, reasoning effort `max`, 6,892 ms. Personal calendars were not transmitted by that check.

## Distribution limits

API credentials are never bundled. Development reads `desktop/.env.day`; installed apps read `day.env` in Electron userData (normally `%APPDATA%/FRI` on Windows). Set `OPENAI_API_KEY`, `DAY_MODEL=gpt-6-luna`, and `DAY_REASONING_EFFORT=max`, then explicitly enable OpenAI in Day. Each user supplies a key for this desktop release. The website and standalone HTML do not offer hosted AI inference.

Windows installer is unsigned. macOS artifacts are unsigned and not notarized; CI success is not physical Mac or Apple-signed-update validation. Updater UI/state tests use mocked release events; they do not by themselves prove a real new-pill installer replacement. Existing profiles stay outside the application directory.
