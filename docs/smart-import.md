# Sources and Refresh · 0.7.0

Open **Sources → Add a source** or **File → Add a source**. Add links, files/images, a selected folder or text, then **Read sources**. A small progress panel replaces the modal, so the calendar stays usable; Cancel stops scheduling further reads and discards late results. An already-sent request may finish at the provider. Required missing details appear one card at a time. **Done** saves a prepared batch; **Add another source** continues collecting. Nothing enters the calendar until **Refresh** in the menu bar.

Refresh resolves all fixed appointments across all prepared batches first, then fits flexible assignment work around them. Valid records are added; conflicting or incomplete records stay as editable Sources. Fixed appointments never move automatically. A retry deduplicates occurrences already added by an earlier partial refresh. Removing source metadata does not delete appointments.

Local readers: ICS, JSON arrays or `{events: [...]}`, CSV columns `title,date,time,duration,kind`, ISO-dated text, HTML event metadata, text-layer PDF and DOCX. PDF/DOCX decoding runs in a bounded worker with no document scripts or linked-resource access. Scanned/protected PDFs need image export/an unlocked copy. Windows local OCR runs before optional model extraction. Unsupported or unreadable files produce source notes; they are not treated as successful appointments.

A bounded cache holds up to 12 extraction results (not original file/image bytes) inside encrypted desktop state. Re-reading identical complex content avoids another model call. Required dates/effort are still validated, and past filtering is re-run. Sources retain provenance in the sidebar; links can be read again without retyping them. This is explicit refresh, not continuous background synchronization.

## What FRI extracts

Each record has a title, fixed start or real deadline, elapsed duration or required work, and a schedule/deadline/task type. Original-language titles and short source evidence are preserved. Weekly timetables ask for their applicable start/end dates. Explicit clock times take precedence over multiplying teaching periods: a five-period session may include breaks. Unknown period length, task effort and preparation days are asked rather than invented.

Assignments retain their actual deadline. Work starts within the window beginning `deadline date − preparation days`, ordered by earliest deadline, then larger effort. The local planner fits blocks into the selected working hours around existing and newly imported fixed appointments, with configurable block length and breaks. It never moves a fixed class. Insufficient capacity is reported; that assignment is not partially scheduled. Overlapping fixed appointments stay in the inbox for adjustment; this import flow has no automatic keep-both action. Completed time intervals and past deadlines are excluded; an ongoing event remains.

Import deduplicates identical source occurrences and equivalent title/date/time/type records. Editing preserves source identity. This is an on-demand import, not background two-way calendar synchronization: a rescheduled or renamed source must be reviewed against the existing calendar. Later deletion does not automatically delete linked work blocks.

## OpenAI setup and cost

Choose **AI settings** to open `%APPDATA%\FRI\ai-config.json` on Windows. Paste the key into `apiKey`, save, and reopen Sources. The native process moves it into OS-protected encrypted storage and clears the editable plaintext field. Never place this file in the repository. `enabled: false` disables AI extraction; the model name can be changed locally.

Default: **gpt-6-luna**, selected from current official documentation on 2026-11-23 for image input and structured output at the lowest applicable published cost. Requests use Responses structured JSON, low reasoning, no tools, `store: false`, a bounded output and no automatic paid retry. The selected source alone is uploaded; existing appointments and sign-in cookies are not supplied to the model. The API key is used only in the authorization header. Local structured parsing, OCR, PDF/DOCX reading, deduplication, date filtering and planning require no AI.

Official references: [model](https://developers.openai.com/api/docs/models/gpt-6-luna), [structured outputs](https://developers.openai.com/api/docs/guides/structured-outputs), [Responses](https://developers.openai.com/api/reference/resources/responses/methods/create). Provider pricing, availability and retention policies can change; `store: false` does not promise zero provider retention under every API account policy.

## Protected links

FRI first checks the public page. A login redirect, password page or authorization response opens a separate **FRI source** browser. The user signs in there, navigates to the relevant page and chooses **Read this page**. This browser has no FRI bridge, Node access, downloads or granted device permissions. Password controls are excluded from captured page text. FRI does not log in on the user's behalf or bypass MFA.

Cookies are encrypted locally and restored in a dedicated partition per origin. **Connected sources → Disconnect** closes that origin, clears its browser storage/cache and removes the saved cookie vault. The provider can expire or revoke a session. Keep the whole application profile when moving/restoring encrypted data: Electron's local encryption metadata is also required; copying ciphertext alone is insufficient.

**Include linked calendar and assignment pages** follows observed read-only Moodle calendar, course and assignment view links on the same origin. It excludes session-token links, submissions, enrolment and other action URLs. This bounded pass reads at most 12 pages/two levels, warns about unread links or text limits, and avoids treating course enrolment ranges as appointments. Import an individual assignment/calendar URL to continue. Other sites support the selected page, readable text or ICS export; universal authenticated crawling is not claimed.

## Calendar files and limits

ICAL.js 2.2.1 parses ICS locally: time zones, recurrence exclusions and moved/canceled exceptions, all-day and overnight events, and VTODO deadlines. Recurrence expansion defaults to 180 days and announces its end date; importing again extends the snapshot. Very large recurrences are rejected rather than freezing the app. Date-only tasks ask for a due time.

Each UI import accepts 15 files/10 links; files up to 8 MB, AI text up to 60,000 characters, extracted records up to 500, and timetable ranges up to one academic year. These bounds protect responsiveness and cost. OCR/AI can misread ambiguous material, login providers can restrict embedded browsers, and a full calendar can have insufficient free time. Review and explicit errors remain part of the product.

## Reproduce verification

```powershell
npm ci --prefix preview
npm ci --prefix tests
npm exec --prefix tests -- playwright install chromium
npm ci --prefix desktop
npm run build --prefix preview
npm test --prefix preview
npm run prepare:ui --prefix desktop
npm test --prefix desktop
npm run dist --prefix desktop
```

Live image/UEH evidence is kept in ignored local test-results, never uploaded with the account's content or session. Public tests use synthetic records and mocked API responses. Desktop 0.7.0 implements this flow; Android and native Apple clients need corresponding adapters and UI before claiming parity. Day opens intake; the separate calendar-insights ranking remains opt-in.
