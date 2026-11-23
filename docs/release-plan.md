# FRI web + desktop release work

Updated 23 November 2026. Current user instruction authorizes GitHub commits, public web deployment on Vercel, desktop packaging and guidebook publication. Premium is **Coming soon**, with no billing. Spotify/Google/account/signing credentials are not available; implement and verify the parts that need no keys first. Never claim keyed integrations are live before configuring and testing them.

## Website acceptance

- [ ] XP-style single-action intro dialog; retain 1.3 second notification burst.
- [ ] Halftone ocean: wave fronts and shoreline both advance/recede, faster cadence, deterministic frame review.
- [ ] One complete app demo spans hero and next scroll area; no duplicate clipped demo.
- [ ] Scramble loop: Fri → mission slogan → pole mark → Fri. Each transition 0.3 s, each hold 1.3 s.
- [ ] Remove the marked arrows, eyebrows, replay/pause/chapter controls and footer micro-links.
- [ ] Steve Jobs quotation with a primary source; continuously moving symbol/wordmark tiles behind legible footer text and under-page reveal.
- [ ] Separate Pricing route with curtain transition and pointer-relative card tilt. Free/current core functions; Premium customization + mutual availability, Coming soon.
- [ ] Frame sequence inspection, responsive/keyboard/reduced-motion tests; commit and deploy the exact verified version to Vercel.

## Desktop acceptance

- [ ] Preserve native translucent main space and existing calendar workflows.
- [ ] Draw an area on the desktop to create a rounded widget; move/resize/remove; responsive information priorities; shared Done state.
- [ ] Windows desktop-icon collision handling with local restoration state and explicit platform capability reporting.
- [ ] Local encrypted storage, no personal calendar upload, validated IPC and network boundaries.
- [ ] Real weather for a manually chosen place/opt-in location. Provider attribution and clear failures.
- [ ] Google Maps/Spotify integration contracts and disconnected states; live provider tests await credentials and permissions.
- [ ] Private mutual availability sharing that does not upload calendar titles/notes; paid entitlement remains unlaunched.
- [ ] Review remaining source/import/reminder interactions against the existing V1, record implemented vs deferred work.
- [ ] Package/test Windows installer upgrade, release artifacts, CI and macOS/iOS handoff.
- [x] Copy the user-provided PDF to `docs/fri_design_guidebook.pdf`; preserve original bytes. Publish with the requested GitHub commit.

## Boundaries

Calendar data stays on-device by default. Opt-in third-party services necessarily receive the request parameters and network metadata needed to answer; Fri does not promise that calling Google/Spotify is invisible to those services. Account/plan infrastructure must not collect calendar content. Never publish keys, tokens, local account data or screenshots of real personal tasks.

Native Windows Acrylic/macOS vibrancy provides real OS background transparency/blur. Do not label a web approximation as the native Apple Liquid Glass compositor. Platform-specific limitations must be tested and documented.

## Progress — 2026-11-23

Website revision 2 implemented and verified: 16 interaction checks, axe zero findings, 276 surf frames captured and reviewed. Premium remains Coming soon. Vercel project fri created in the existing ACNE team; deployment pending this checkpoint.

Desktop work in progress: encrypted native store, selector and responsive widget, Windows icon adapter, opt-in weather and isolated Spotify player. These changes are not yet release-verified.
