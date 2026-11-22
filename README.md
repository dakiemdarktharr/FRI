# Fri

Fri is a personal calendar for appointments, flexible work, deadlines, and travel. The web app is a single HTML file with an English interface and a beige, near-black brown, and rosewood glass theme.

## Run

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

## Verify

The app has no install step. The test suite uses Node.js 24, Playwright, and a local HTTP server started by the tests.

```powershell
npm ci --prefix tests
npm exec --prefix tests -- playwright install chromium webkit
npm test --prefix tests
$env:FRI_BROWSER = 'webkit'
npm run test:browser --prefix tests
Remove-Item Env:FRI_BROWSER
```

Run `npm run test:domain --prefix tests` for calendar and scheduling logic alone. [GitHub Actions](.github/workflows/web.yml) also runs both browser engines. [Architecture and technology](docs/technology.md) covers the implemented stack, data contracts, and platform roadmap.

Verified on Windows with 14 domain cases and 18 browser cases each in Chromium and WebKit. Coverage includes the preview delays, square tile layout, keyboard and 360 px touch navigation, completion persistence, widget navigation, and the appointment, sources, and planner workflows.
