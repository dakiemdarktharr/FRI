# FRI

Fri is a personal calendar that makes room for appointments, focused work, and the everyday things that matter.

**Website design preview:** open [FRI-website.html](FRI-website.html) for the overload-to-calm intro, animated ocean, staged app demo and platform-aware installer links. It is a self-contained design review. [Website notes and verification](website/README.md) describe its scope; Pricing and Sign up are preview states.

**Desktop installers:** [GitHub Releases](https://github.com/dakiemdarktharr/FRI/releases). **Single-file interface:** [FRI-liquid-glass.html](FRI-liquid-glass.html). The current design is black and white, with a slow monochrome sidebar, multiple day tabs, a duration-sized appointment mosaic and Day beside Up Next.

The Electron desktop app uses native Windows Acrylic or macOS vibrancy to reveal blurred wallpaper and applications behind main space. HTML uses a sample background. Acrylic/vibrancy is real native transparency and blur; it is not Apple's native Liquid Glass refraction renderer. The earlier V1 remains in [index.html](index.html), with its separate sources, planner and data model.

## Try the new interface

Double-click `FRI-liquid-glass.html`, or launch the desktop app. Start on today, open another day with **+** beside the tabs, and close a day with its **×**. Search is the magnifying glass beside the logo. **New** offers **One-time deadline** (due date/time) or **Schedule** (one appointment with start/duration). Recurrence is not implemented. Use **…** for layout, editing and bulk deletion. **Settings** changes sidebar background, uploaded image, motion, transparency and text size. The palette is intentionally monochrome for the next design review.

**Add → name and details → Add another → Done** gathers a batch. Missing information is requested one card at a time; schedules are checked for overlap. Deadlines do not require duration. Complete individual tasks to unlock the day ring. Delete offers Undo. `N` opens New, `/` or `Ctrl/⌘ F` searches, `Ctrl/⌘ B` toggles the sidebar, and Escape closes a menu/dialog. File/Edit/View/Help provide backup/restore, editing, day/month/year views, shortcuts and updates. Window controls operate the real desktop window.

Up Next uses the local calendar. Weather, Maps, Spotify and Health contain labeled sample content. Day is a local demo; spoken playback depends on platform support, and the native preview does not request microphone access. Accounts, connected services, native OS widgets and background reminders are not implemented. Calendar backups transfer tasks between browser and app; preferences and drafts remain local.

Current implementation, packaging and limitations are in [desktop ground truth](docs/desktop.md). [Liquid Glass research](docs/liquid-glass-research.md) preserves the earlier beige/marsala design history.

## Desktop and Docker

Use Node.js 24+:

```powershell
npm ci --prefix preview
npm run build --prefix preview
npm ci --prefix desktop
node desktop/node_modules/electron/install.js
npm start --prefix desktop
npm run dist --prefix desktop
```

Windows produces `dist/FRI-0.2.0-win-x64.exe`. Its assisted per-user installer replaces the old application in the registered folder and keeps calendar data in a separate user-data directory. Help → Check for updates downloads newer GitHub releases and offers restart/install. Old files are removed during installation, after the download succeeds.

Initial packages are unsigned. macOS DMG/ZIP builds come from the macOS CI runner; automatic installation there awaits Apple signing/notarization. Replacing FRI in Applications preserves its user Library data. Windows glass needs Windows 11 22H2+; older systems use a solid fallback.

`docker compose up --build -d` serves the browser interface at [localhost:8080](http://127.0.0.1:8080). The container runs non-root nginx and does not provide desktop transparency. Stop with `docker compose down`.

To rebuild or test the preview:

```powershell
npm ci --prefix preview
npm run build --prefix preview
npm ci --prefix tests
npm exec --prefix tests -- playwright install chromium webkit
npm test --prefix preview
$env:FRI_BROWSER = 'webkit'
npm test --prefix preview
Remove-Item Env:FRI_BROWSER
```

Verified on Windows: **8 scenario tests in Chromium and 8 in WebKit**, covering offline loading, mosaic geometry, batch review, overlap, editing/deletion/undo, completion, tabs, hover timing, settings, widgets and accessibility semantics. `npm test --prefix desktop` adds native isolation/IPC, window controls, deadline persistence after restart, monochrome menus, narrow layouts and invalid-backup rejection. Native foreground inspection confirmed blurred applications behind main space. `npm audit --prefix desktop` reports zero vulnerabilities with the current lockfile. Translucent contrast depends on the backdrop; this is not a claim of full accessibility conformance.

Authoring files and dependency lockfile live in `preview/`. The output includes [third-party notices](preview/THIRD-PARTY-NOTICES.txt). The reusable `moving_gradient_bg` skill is installed locally with canonical ID `moving-gradient-bg`.

## Run the earlier V1

Open `index.html` directly in a modern browser. The app and sample assets are self-contained. For a stable storage origin and to try public calendar sources, run this command from the repository root:

```powershell
python -m http.server 8000 --bind 127.0.0.1
```

Open [Fri on localhost](http://127.0.0.1:8000/). The demo day is Monday, November 23, 2026 in `Asia/Ho_Chi_Minh`. Use **Settings → Manage data → Empty calendar** to start with your own calendar.

## Calendar and widgets

- **Day** opens first. Activities appear as posts with a time tile, title, and a check box for each trackable item. Hover for 300 ms to preview details or open the post by clicking, tapping, or pressing Enter.
- **Month** and **Year** use rounded square tiles. The month tiles bobble when the pointer enters and show a cursor-following agenda preview after 500 ms. Pick a month or day to go one level deeper. Use the arrow keys to navigate days in Month.
- The progress ring tracks appointments, flexible tasks, nested activities, and deadlines. The day-level check unlocks when every trackable activity is complete. Reopening an activity clears the day-level completion. Travel and on-site context appear in the feed and progress is unchanged by them.
- The square **widget** shows progress and the next activity. Open it to expand the upcoming stack, then select an item to open its details. **Widgets** includes a lock screen preview and system tint. Native widgets and background notifications belong to later platform releases.
- **Settings** includes alternate palettes, light and dark appearances, and reduced transparency. The app uses the Apple system font where available and platform fallbacks elsewhere. The calendar respects reduced motion.

The motion treatments are implemented with CSS and the Web Animations API. [Motion references for bobble](https://motion.dev/examples/react-bobble-hover), [cursor-following previews](https://motion.dev/examples/vue-cursor-hover-follow), [stagger](https://motion.dev/examples/vue-staggered-grid), [post expansion](https://motion.dev/examples/js-app-store-layout), and the [widget stack](https://motion.dev/examples/vue-notifications-stack).

## Add appointments and sources

Choose **Add appointment** and enter a name. Use **New appointment** to add another, then choose **Done**. Fri asks for any missing or invalid date, start time, or end time one card at a time. The full batch goes on the calendar after the final answer. Closing or reloading keeps the draft.

Use **Add sources** to stage images, text, and calendar links. The sample batch includes two images, an ICS calendar, and a login-required source. Public ICS and JSON-LD depend on the source’s browser access policy. Uploaded images have a local preview and go through manual review. **Plan tasks** previews schedule changes, explains issues, and applies a validated revision before exporting generated sessions as ICS.

## Verify the earlier V1

The earlier V1 HTML has no install step. Its test suite uses Node.js 24, Playwright, and a local HTTP server started by the tests.

```powershell
npm ci --prefix tests
npm exec --prefix tests -- playwright install chromium webkit
npm test --prefix tests
$env:FRI_BROWSER = 'webkit'
npm run test:browser --prefix tests
Remove-Item Env:FRI_BROWSER
```

Run `npm run test:domain --prefix tests` for calendar and scheduling logic alone. [GitHub Actions](.github/workflows/web.yml) also runs both browser engines. [Architecture and technology](docs/technology.md) covers the implemented stack, data contracts, and platform roadmap.

Verified on Windows with 14 domain cases and 19 browser cases each in Chromium and WebKit. Coverage includes the solid palette, preview delays, square tile layout, keyboard and 360 px touch navigation, completion persistence, widget navigation, and the appointment, sources, and planner workflows.
