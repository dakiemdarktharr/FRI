# FRI 0.7.0 verification

2026-11-24, Windows host. Accepted direction: [Cloud feed](cloud-feed-redesign.md).

## Observed locally

- Preview: 38 tests passed on WebKit; six intake browser regressions passed on Chromium. Covers staged/persisted sources, missing fields, partial conflict application, retry/dedup, JSON/CSV/HTML, image fallback, remembered-source flow with mocked authorization, same-day cache reuse, next-day cache invalidation, cancellation and direct ICS links.
- Desktop: 69 tests passed with isolated hidden windows. Covers encrypted state, IPC restrictions, scheduling, Day suggestions, providers, updater transitions, source reader limits and widget creation/movement/resizing/Done/removal/restart. Hidden mode omits native maximize/minimize/restore interaction; CI runs those on its own desktop.
- Packaged app: six integration tests passed, plus a real PDF through the packaged worker after unused PDF viewer/source-map assets were excluded. Document tests also cover DOCX, invalid/oversized inputs and scanned PDFs without text.
- Supplied timetable image: six classes, one optional model request, shared date-range answers, zero calendar writes before Refresh and six afterward in an isolated profile. Durations were 210 and 260 minutes as stated by the image's actual clock ranges. No user source content or credentials were committed.
- UEH URL returned `sign-in` with the saved local vault. Recognition of reconnect works; a currently valid remote login was **not** verified this time. Server sessions can expire.
- Accessibility: zero axe WCAG A/AA violations across light/dark Feed, Settings and Sources. This is automated evidence, not complete assistive-technology certification.
- Website: 18 checks across Chromium/WebKit; six responsive widths from 320 to 1440; zero Chromium axe violations. Autoplay works in Chromium without clicking. Windows WebKit cannot decode the installed video codecs; both Linux CI engines verified playback on the previous release candidate. Final CI is linked below once complete.
- Ocean: 276 consecutive halftone frames checked at 30 fps. The new widget film captures actual native UI on a neutral virtual desktop, documented in [asset notice](../website/assets/NOTICE.md). It does not claim Explorer icon collision proof.
- Upgrade: the existing Windows 0.6.1 installation was replaced by 0.7.0 with NSIS exit 0. The user's encrypted calendar bytes were unchanged by installation; an isolated seeded deadline and large-text preference survived the upgrade.
- Android 0.2.0: ARM64 and x86_64 optimized local APKs built; lint/typecheck passed; two Room instrumentation tests passed. On a hidden API 35 Pixel launcher, install-over-old preserved data; pin, move, resize 3×2 → 5×4, Done (2/2) and Remove were exercised. Larger size revealed progress without enlarging text. ARM64 hardware remains untested.

## Artifacts

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| FRI-0.7.0-win-x64.exe | 127307640 | `070823dd23787dcd3495d1a816eb995118468110194e667f6199169d15fa62e3` |
| FRI-0.2.0-android-arm64.apk | 31591959 | `0c60efe1851a4208df847ddbb3cb44dac32e6180696058b1c866a2e9f2f66b5f` |
| FRI-0.2.0-android-x86_64.apk | 32168100 | `b52a88b22c1904cba67d5130ea5fbaf2dedde2adcba78ef046c816587ac30b1c` |

The standalone app HTML is about 1.64 MB, down from about 4.62 MB. Local PDF/DOCX support adds runtime dependencies; excluding unused PDF viewers/maps reduced the new Windows installer from 132.1 MB to 127.3 MB. It remains larger than 0.6.1. Native glass and its fallbacks were preserved; compositor optics and Explorer icon displacement were not revalidated on the user's live desktop during this hidden run.

Windows is unsigned. Android APKs use the local debug signing key and remain local alpha builds, not store releases. Figma connector requires reauthentication. Android source import and music/maps/weather parity remain outstanding; desktop integrations retain their existing opt-in behavior. No payment or account service was enabled.

## Reproduce

```powershell
npm run build --prefix preview
npm test --prefix preview
$env:FRI_BROWSER='webkit'
npm test --prefix preview
Remove-Item Env:FRI_BROWSER
npm run prepare:ui --prefix desktop
npm test --prefix desktop
npm test --prefix tests
npm run dist --prefix desktop
node desktop/verify-package.cjs
node website/build.mjs
node website/verify-v2.cjs
node website/verify-responsive.cjs
npm run lint --prefix mobile
npm run typecheck --prefix mobile
```

Use `FRI_TEST_HIDDEN=1` to keep local Electron checks off the main screen; native window-state checks then require a separate visible CI run. See [Android build commands](../mobile/README.md). Raw screenshots/logs are in ignored `test-results/cloud`, not public fixtures. CI and deployment receipts are tracked in PR #3 and the GitHub release. The final source-cache correction is commit c61b440. Reload persistence uses a seeded HTTP origin in the browser test; file-URL localStorage behavior is browser-dependent ([MDN](https://developer.mozilla.org/en-US/docs/Web/API/Window/localStorage)). Native encrypted restart is checked independently.
