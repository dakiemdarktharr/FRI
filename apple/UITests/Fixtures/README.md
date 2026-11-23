# Native import fixtures

These files contain synthetic plans only. They are used for native file-picker and review checks.

- `import-review.ics`: one all-day event on 2026-11-24. Review must request a time and duration. Completing a clarification and closing the editor must retain that edit. Importing the same UID again must not duplicate it.
- `import-review.csv`: a 09:15 / 35 minute schedule with a comma in its title and a 12:00 deadline, both on 2026-11-24.
- `import-text.pdf`: selectable text, `QA PDF import 2026-11-25 10:00`.
- `import-image.png`: raster text, `QA image import 2026-11-25 10:30`.
- `import-scan.pdf`: image-only PDF, `QA scanned import 2026-11-25 11:00`; requires OCR rather than PDF text extraction.

The PDF/image fixtures can be regenerated on macOS from the repository root:

```sh
swift apple/Tools/GenerateImportFixtures.swift apple/UITests/Fixtures
```

For the three PDF/image plans, review the extracted name/date/time, enter 20 minutes for each, and confirm all three appear on Nov 25. This checks import behavior on controlled, legible text; it does not establish OCR accuracy for arbitrary photographs or every language.
