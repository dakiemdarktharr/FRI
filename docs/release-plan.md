# FRI web + desktop release work

Updated 23 November 2026. Current user instruction authorizes GitHub commits, public web deployment on Vercel, desktop packaging and guidebook publication. Premium is **Coming soon**, with no billing. Spotify/Google/account/signing credentials are not available; implement and verify the parts that need no keys first. Never claim keyed integrations are live before configuring and testing them.

## Current milestone — v0.6.1 smart import

Windows 0.6.1 adds optional OpenAI image/page extraction, isolated source sign-in, encrypted remembered cookies, missing-field cards, local deadline planning, past filtering and richer ICS handling. [Behavior and limits](smart-import.md). macOS 0.6.1 artifacts passed the Intel CI suite and package checks; they remain unsigned development builds; Apple/Android import parity is not yet implemented.

## Previous milestone — v0.5.0 and Android local alpha

Desktop 0.5.0 and the revised website are released. Eight answer-led product sections use headlines and motion diagrams. Fri colors pair an actual glass workspace with opaque cards and controls. Desktop widgets reveal more content with size; empty slots use +. The installer is 6.8% smaller and unpacked footprint 12.9% smaller.

Android now has an offline Expo/Room calendar and two native Glance widgets. Optimized ARM64/x86_64 APKs build locally; actual API 35 launcher checks cover creation, cancellation, reconfiguration, independent filters, Done, moving/resizing/removal and reboot persistence. Android integrations and broad physical-device coverage remain pending. APKs are not publicly released.

See [0.5 receipt](release-verification-0.5.0.md) and [Android receipt](../mobile/docs/verification.md). The public desktop video still shows 0.4.0: re-recording the 0.5 layout awaits dismissal of a Windows Security prompt.

## Website acceptance

- [x] XP-style single-action intro dialog; retain 1.3 second notification burst.
- [x] Halftone ocean: wave fronts and shoreline both advance/recede, faster cadence, deterministic frame review.
- [x] One complete app demo spans hero and next scroll area; no duplicate clipped demo.
- [x] Scramble loop: Fri → mission slogan → pole mark → Fri. Each transition 0.3 s, each hold 1.3 s.
- [x] Remove the marked arrows, eyebrows, replay/pause/chapter controls and footer micro-links.
- [x] Steve Jobs quotation with a primary source; continuously moving symbol/wordmark tiles behind legible footer text and under-page reveal.
- [x] Separate Pricing route with curtain transition and pointer-relative card tilt. Free/current core functions; Premium customization + mutual availability, Coming soon.
- [x] Frame sequence inspection, responsive/keyboard/reduced-motion tests; commit and deploy the exact verified version to Vercel.

## Desktop acceptance

- [x] Preserve native translucent main space and existing calendar workflows.
- [x] Draw an area on the desktop to create a rounded widget; move/resize/remove; responsive information priorities; shared Done state.
- [x] Windows desktop-icon collision handling with local restoration state and explicit platform capability reporting.
- [x] Local encrypted storage, no personal calendar upload, validated IPC and network boundaries.
- [x] Real weather for a manually chosen place, with attribution and failure/cached states. Automatic location tracking is not enabled.
- [x] Interactive OpenStreetMap view and isolated Spotify Embed, with explicit provider disclosure. Embedded Places data and OAuth account playback remain unconfigured.
- [x] Private mutual availability sharing that does not upload calendar titles/notes; paid entitlement remains unlaunched.
- [x] Review remaining source/import/reminder interactions against the existing V1, record implemented vs deferred work.
- [x] Package/test Windows installer upgrade, release artifacts, CI and macOS/iOS handoff.
- [x] Copy the user-provided PDF to `docs/fri_design_guidebook.pdf`; preserve original bytes. Publish with the requested GitHub commit.

## Boundaries

Calendar data stays on-device by default. Opt-in third-party services necessarily receive the request parameters and network metadata needed to answer; Fri does not promise that calling Google/Spotify is invisible to those services. Account/plan infrastructure must not collect calendar content. Never publish keys, tokens, local account data or screenshots of real personal tasks.

Native Windows Acrylic/macOS vibrancy provides real OS background transparency/blur. Do not label a web approximation as the native Apple Liquid Glass compositor. Platform-specific limitations must be tested and documented.

## Historical milestone — v0.3.0

Website revision 2 and the Windows-first 0.3.0 keyless release are built and verified. Premium remains Coming soon. Desktop/container CI passed on Windows and macOS; web CI passed on Chromium and WebKit. All 15 release assets were uploaded to GitHub and their SHA-256/SHA-512 hashes checked. Website: https://fri-acne-a6cd.vercel.app . Release: https://github.com/dakiemdarktharr/FRI/releases/tag/v0.3.0 . Publication/deployment receipts are in release-verification.md.

The Windows installer upgrade retained eight saved appointments and settings, removed an obsolete file and left one uninstall entry. Native widget lifecycle, local OCR/import, encrypted restart, real Acrylic background and desktop-icon restoration were exercised. Website review includes 276 consecutive surf frames plus curtains, scramble and demo states. See web-verification-2026-11-23.md.

Remaining configured-service/platform work: signing/notarization, account/plan infrastructure, OAuth playback, Google Places/Routes, automatic shared-calendar linking, cloud/multimodal Day and native Apple widgets/iOS. The new desktop does not expose the research workspace's recurrence, overnight/nested travel planner. Privacy boundaries, actual service behavior and unsupported platform cases are explicit in README, privacy.md and apple-handoff.md.
