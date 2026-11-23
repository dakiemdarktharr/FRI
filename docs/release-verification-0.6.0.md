# FRI 0.6.0 — Day and update controls

Published on 23 November 2026 as [v0.6.0](https://github.com/dakiemdarktharr/FRI/releases/tag/v0.6.0), built from `0c25eecd3dc30f374d3b9645ad6ed81161195f49`. Day and the update control were integrated into main at `f68fb84`; the following commit only selected the Intel macOS CI runner.

## Published evidence

- [Desktop and container CI](https://github.com/dakiemdarktharr/FRI/actions/runs/45183517615): Windows, macOS Intel runner and container jobs all passed. The macOS job produced both arm64 and x64 distributions. An earlier run was cancelled while the arm64 runner remained queued; its Windows and container jobs had passed.
- [Web CI](https://github.com/dakiemdarktharr/FRI/actions/runs/45183492019): Chromium and WebKit passed, including preview, website interactions and responsive checks.
- Every uploaded asset was downloaded and checked against GitHub's SHA-256 digest. Both updater manifests' artifact sizes and SHA-512 values matched the downloads. [SHA256SUMS.txt](https://github.com/dakiemdarktharr/FRI/releases/download/v0.6.0/SHA256SUMS.txt) accompanies the release.
- Both macOS ZIPs passed ASAR inspection for Day/update modules and absence of credential files. The executable headers confirmed arm64 and x64 respectively. This is artifact inspection, not a physical Mac installation test.
- The [marketing website](https://fri-acne-a6cd.vercel.app/) download links in `website/page.html` and the generated `FRI-website.html` now target 0.6.0.

## Changes

- Proactive Day receives the existing calendar, detects conflicts, proposes user-confirmed moves for flexible work, and reminds deadlines within 24 hours. Optional OpenAI GPT-6 Luna at max reasoning ranks validated suggestions. [Architecture and configuration](day-ai.md).
- A Codex-style title-bar update pill follows the requested WWW reference's separation of UI state and privileged updater work. Windows downloads on click and restarts only after confirmation and saved calendar writes. macOS uses the official release-download page. [Updater architecture](updater.md).
- Windows widget geometry no longer grows during movement at fractional DPI. The native regression covers repeated no-op/move operations at observed 125% scaling, exact resizing, encryption and persistence; pure geometry cases cover 100/125/150/175/200%.
- Container builds now include the shared Day planner without including the desktop credential directory. Preview tests use the selected Chromium/WebKit engine.

## Local evidence

- Desktop suite: 62/62 passed.
- Preview: 17/17 Chromium and 17/17 WebKit passed.
- Network-boundary test passed; production dependency audit found zero vulnerabilities.
- Website interaction checks after updating download links: 9 Chromium checks passed, axe returned no violations.
- Windows NSIS built successfully. ASAR inspection confirmed version 0.6.0, all Day/update modules, no credential files or project tests, and exact runtime/source matches.
- The actual unpacked Windows executable passed all 5 native/calendar/Day/widget checks, including Day apply and restart persistence. The Windows installer uploaded by CI was downloaded, its SHA-256 and manifest SHA-512 checked, and its extracted application independently passed the same 5 checks. Its ASAR also passed the module/credential inspection.
- Day's OpenAI connection was tested with one synthetic request: structured output valid, model `gpt-6-luna`, reasoning effort `max`, 6,892 ms. Personal calendars were not transmitted by that check.

## Distribution limits

API credentials are never bundled. Development reads `desktop/.env.day`; installed apps read `day.env` in Electron userData (normally `%APPDATA%/FRI` on Windows). Set `OPENAI_API_KEY`, `DAY_MODEL=gpt-6-luna`, and `DAY_REASONING_EFFORT=max`, then explicitly enable OpenAI in Day. Each user supplies a key for this desktop release. The website and standalone HTML do not offer hosted AI inference.

Windows installer is unsigned. macOS artifacts are unsigned and not notarized; CI success is not physical Mac or Apple-signed-update validation. Updater UI/state tests use mocked release events; they do not by themselves prove a real new-pill installer replacement. Existing profiles stay outside the application directory.

An existing FRI installation was detected on the verification machine. The isolated installer-replacement test was therefore not run; the user's installed application was preserved.
