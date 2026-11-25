# Calendar assistant · Android share flow

Android 0.3.0 ports the **explicit share** path selected by the user on 2026-11-25. It uses the same recognition rules as native Apple build 4 and Windows. It does not continuously read another application or request MediaProjection/accessibility access.

## Use

From a chat or Photos, choose **Share → Fri · Review a plan** for text or a single image. Fri reads images using bundled Vietnamese Tesseract OCR on the device, then opens **Make it a plan.** Review the extracted text, choose an invitation and confirm the calendar, date, time and duration in the normal Fri editor. **Save plan** is the only action that writes an event. Cancel leaves the calendar unchanged. Settings → Calendar assistant also supports pasted text.

“ê xíu 9h trạm k” keeps its location and ambiguous time hint. Date and AM/PM remain unfilled. Past appointments, duplicates and overlapping fixed events are rejected at the native save boundary, using the selected time zone; existing plans stay put. Larger app-wide import/planning functionality is a separate feature.

## Design

Use the existing Cloud `#F4F7FA`, Ink `#172B3A`, Teal `#087F8C` palette, shared Page/Card/Button components, 16–17 sp body type, 16–20 dp radii, 48 dp targets and the app's dark preference. The brief native reading screen uses the same palette. System sharing, date/time pickers and the launcher remain Android-owned surfaces.

## Privacy and limits

- No new account, API key, network OCR, analytics, microphone, broad photo-library permission or overlay permission.
- Only the image URI explicitly shared by the source app is read. `file://` and Fri's own providers are rejected. The image is bounded to 12 MB and downsampled to at most 2048 pixels on the longest edge before recognition; EXIF orientation is applied.
- Raw text and image buffers remain in memory. A random, single-use token transfers text to the app; content is never placed in a deep-link URL, log or Room. Unconsumed shares expire after ten minutes. The app does not copy screenshots to disk; the offline OCR model is extracted to private no-backup storage.
- OCR can be wrong. Users can correct extracted text. At most eight candidate invitations from the first 60 nonempty lines are proposed; each is reviewed separately. No background source monitoring, sender identity inference or automatic calendar writes are claimed.
- The Windows build currently recognizes new confirmed messages in a chosen Zalo/Messenger window. macOS's unsent Zalo-composer panel has not been ported to this Windows build.

## Reproduce

```powershell
cd mobile
npm ci
npm run prepare:meeting
npm run lint
npm run typecheck
node --test scripts/meeting.test.cjs
npm run prebuild -- --no-install
# JDK 21 / SDK / short Windows paths: see ../README.md
./android/gradlew.bat -p android :app:assembleRelease :fri-android:testDebugUnitTest :fri-android:assembleDebugAndroidTest -PreactNativeArchitectures=x86_64 --no-daemon --max-workers=2
```

Build each ABI separately. Keep the established alpha signing key for install-over-old testing. `prepare:meeting` copies the canonical JS rules and the pinned `@tesseract.js-data/vie` model into ignored generated directories. No separate mobile copy of the recognition rules is maintained.

## Upstream references

- [Android receiving shared data](https://developer.android.com/develop/ui/compose/sharing/receive): ACTION_SEND and temporary URI grants.
- [Expo SDK 58 Router](https://docs.expo.dev/versions/v58.0.0/sdk/router/) and [native-intent routing](https://docs.expo.dev/router/advanced/native-intent/).
- [Tesseract4Android 4.9.0](https://github.com/adaptech-cz/Tesseract4Android/tree/4.9.0): Apache-2.0 JNI wrapper, offline Tesseract 5.5.1; includes Leptonica, libjpeg and libpng under their upstream licenses.
- [Vietnamese trained data](https://github.com/tesseract-ocr/tessdata/tree/4.0.0): Apache-2.0. The pinned npm package only supplies that model; it is a build dependency, not a network service.

See the rebuild receipt for observed device tests and artifact hashes; compilation alone is not evidence of physical-device or alternate-launcher support.
