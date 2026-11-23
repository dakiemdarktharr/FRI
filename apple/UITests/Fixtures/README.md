# Native import fixtures

These files contain synthetic plans only. They are used for native file-picker and review checks.

- `import-review.ics`: one all-day event on 2026-11-24. Review must request a time and duration. Completing a clarification and closing the editor must retain that edit. Importing the same UID again must not duplicate it.
- `import-review.csv`: a 09:15 / 35 minute schedule with a comma in its title and a 12:00 deadline, both on 2026-11-24.
- `import-text.pdf`: selectable text, `QA PDF import 2026-11-25 10:00`.
- `import-image.png`: raster text, `QA image import 2026-11-25 10:30`.
- `import-scan.pdf`: image-only PDF, `QA scanned import 2026-11-25 11:00`; requires OCR rather than PDF text extraction.
- `invalid-zero-duration-backup.json`: deliberately invalid completed-calendar entry (a schedule with no duration). Select it through Restore Backup; the app must report an invalid backup, show no replacement confirmation and leave the current calendar unchanged. Zero duration remains valid for a deadline or an unfinished draft.
- `desktop-service-cache-backup.json`: synthetic desktop-format Weather cache with a deliberately old millisecond timestamp, plus a legacy mapsRegion name. Use a separate QA store. The rail must label the weather as cached; Services must show both saved values and allow Disconnect to remove them completely.

- `auto-refresh-weather-backup.json`: stale Hanoi Weather with saved coordinates, empty tasks, a legacy map name and Larger text. Restore in an isolated QA store while online; the forecast should update automatically without pressing Refresh. Export must preserve the rest of the fixture. This exercises a live provider and must not be treated as a deterministic offline test.

The PDF/image fixtures can be regenerated on macOS from the repository root:

```sh
swift apple/Tools/GenerateImportFixtures.swift apple/UITests/Fixtures
```

For the three PDF/image plans, review the extracted name/date/time, enter 20 minutes for each, and confirm all three appear on Nov 25. This checks import behavior on controlled, legible text; it does not establish OCR accuracy for arbitrary photographs or every language.

## Availability Files-picker integration

`testAvailabilityFileWorkflow` is opt-in because it exercises the system Files UI and needs external fixture setup. Generate synthetic files into a **FRI QA Availability** folder in the selected simulator's **On My iPad / On My iPhone** storage:

```sh
python3 apple/Tools/PrepareAvailabilityFixtures.py '/absolute/path/to/FRI QA Availability'
```

Use the simulator's local date and time zone when generating (the script uses the host's defaults; `--day YYYY-MM-DD` overrides the date). On Simulator, the local Files storage is the `File Provider Storage` directory in the `group.com.apple.FileProvider.LocalStorage` shared container. Resolve its UUID from that simulator's container metadata; never use another simulator's or the host's personal Files folders.

Enable `FRI_AVAILABILITY_PICKER_TESTS=1` in the **test runner** environment and run only `FRIiOSUITests/FRIWorkflowTests/testAvailabilityFileWorkflow`. Picker navigation supports the English/Vietnamese On My iPad / On My iPhone labels; keep the simulator's date and time zone aligned with fixture generation. It launches a fresh UUID-scoped synthetic app store and creates a private 09:00–10:00 appointment through the UI. `matching.json` must yield one 10:00–10:30 slot (duplicate overlaps deduplicated, 25-minute slot excluded); `no-match.json` must yield an empty result. `invalid.json` and `oversized.json` must show specific errors while preserving the appointment. The test also cancels both dialogs, exports a uniquely named JSON, and reads it back through the picker.

The exported `availability-export-<UUID>.json` remains in the QA folder for independent read-back: seven windows, first day 10:00–18:00 and the next six days 09:00–18:00, with only `format`, `version`, `generatedAt`, and `windows` at the top level. No appointment title, notes or location may appear. Use `preview/planning.cjs` to validate it with the shipping desktop parser. The test intentionally skips unless enabled; a skip is not runtime evidence.
