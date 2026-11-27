# Fri for Android · 0.4.2 local alpha

Native home-screen widgets backed by the same Room database as the Expo app. No login, server, analytics, calendar permission or cloud account is required. This is the Android starting point; it is not a claim of complete Windows feature parity.

## Build locally

Pinned versions live in package-lock.json and modules/fri-android/android/build.gradle. Expo SDK 58, React Native 0.88.1 and React 19.3.0 use the New Architecture. Use JDK 21 and Node 22 or newer. The generated project currently compiles with Android API 37, targets API 36 and supports API 24+. Install SDK platform `platforms;android-37.0`, build tools 37.0.0, NDK 27.1.12297006, CMake 3.22.1 and platform-tools. Accept SDK licenses locally.

```powershell

cd mobile

npm ci

$env:JAVA_HOME='C:/Program Files/Android/openjdk/jdk-21.0.8'

$env:ANDROID_HOME='D:/FRI-work/android-sdk'
$env:PATH="$env:ANDROID_HOME/platform-tools;$env:ANDROID_HOME/emulator;$env:PATH"

$env:GRADLE_USER_HOME='D:/FRI-work/gradle'

$env:FRI_NATIVE_BUILD_ROOT='D:/FRI-work/cxx'

$env:NODE_ENV='production'

npm run prebuild -- --no-install

./android/gradlew.bat -p android :app:assembleRelease :fri-android:testDebugUnitTest -PreactNativeArchitectures=arm64-v8a --no-daemon --max-workers=2

```

Use `x86_64` for the emulator. The output is `android/app/build/outputs/apk/release/app-release.apk`. This local alpha uses the generated **debug signing key**, even though release optimization and bundled JavaScript are enabled. It is not store-signed. Keep a copy of your signing key for future in-place updates; prebuild clean can regenerate native files. Do not publish this APK as a production release.

On Windows a short `FRI_NATIVE_BUILD_ROOT` and `CMAKE_OBJECT_PATH_MAX=250` prevent Ninja's 260-character path failure. The config plugin applies this reproducibly; do not hand-edit generated android/. SDK 58 prebuild recreates native folders by default; use --no-clean for incremental config changes. Java time APIs are desugared with Google’s desugar_jdk_libs 2.1.5 for API 24/25 compatibility. Build one ABI at a time to keep the APK small. R8 and resource shrinking are enabled. No EAS account or paid build service is involved.

```powershell

npm run lint

npm run typecheck

npx expo-doctor

npm audit

adb install -r android/app/build/outputs/apk/release/app-release.apk

adb shell am start -a android.intent.action.VIEW -d 'fri://'

```

For development, use `npm run android` then `npm start` with the development client. Expo Go cannot load this local Kotlin module. A release APK runs without Metro.

## Phone or one emulator

For a phone, enable Developer options and USB debugging, connect USB and approve that computer on the phone. `adb devices` must show `device`, not `unauthorized`. Use `npx expo run:android --device` to select it and build a development client. Once installed, JavaScript-only changes need `npm start`; Kotlin, manifest or resources require another native build. Install the ARM64 release APK with `adb -s DEVICE_SERIAL install -r PATH_TO_APK` to test without Metro. Do not clear app data for an upgrade test.

For an emulator, install `emulator` and `system-images;android-35;google_apis;x86_64` using SDK Manager. Create a Pixel 4 AVD named Fri_API_35 with that image. On this machine its dedicated data directory is D:/FRI-work/avd/Fri_API_35.avd. Start **one** instance:

```powershell
emulator -avd Fri_API_35 -memory 2048 -gpu auto -no-snapshot-save
adb devices
adb install -r ../dist/android/FRI-0.2.0-android-x86_64.apk
```

For automated capture, `-no-window -no-audio` starts the same Android launcher without a Windows emulator window. Guest RAM is 2 GB; total emulator memory is higher. CPU virtualization must be available. Keep SDK/AVD data on a drive with adequate free space; initial userdata creation can require about 12 GB. Close Android Studio after setup, and avoid simultaneous native builds. API 35 guest testing does not lower the app's API 36 target. Android 17/API 37 AVDs need more RAM and are not the low-memory default.

## Native tests and launcher acceptance

```powershell
./android/gradlew.bat -p android :fri-android:testDebugUnitTest :fri-android:assembleDebugAndroidTest -PreactNativeArchitectures=x86_64
adb install -r modules/fri-android/android/build/outputs/apk/androidTest/debug/fri-android-debug-androidTest.apk
adb shell am instrument -w expo.modules.friandroid.test/androidx.test.runner.AndroidJUnitRunner
```

The instrumentation APK is a separate test package using an in-memory Room database. It does not clear Fri data. Remove only that test package after testing (`adb uninstall expo.modules.friandroid.test`) so its test providers do not clutter the widget picker. Check both normal and **optimized release** APKs: Glance callback classes are instantiated reflectively, so a passing debug test alone cannot validate R8 behavior.

On the launcher, exercise both add paths: configure in Fri then confirm the system pin dialog; and long-press an empty home-screen area → Widgets → Fri → choose a template → configure → Add widget. Long-press a placed widget to move/resize, use the pencil to reconfigure when supported, or drag to Remove. Cancellation must leave existing widgets and presets unchanged. See the observed results and remaining coverage in docs/verification.md.

## Native ownership

- `src/app`: Expo Router Today, Calendar, event detail/edit, Widgets and Settings screens.

- `src/lib/fri.ts`: typed bridge. JavaScript does not maintain a second calendar store.

- `modules/fri-android`: Room entities/DAO, UTC and local-date rules, Compose configuration, two Glance providers, pin callback, lifecycle reconciliation and WorkManager.

- `plugins/with-fri.cjs`: reproducible native settings, backup disabled and bounded build memory.

- `docs/architecture.md`: data, widget states, links and privacy boundaries.

- `docs/verification.md`: observed checks and remaining device/launcher coverage. Read it before claiming release readiness.

The actual launcher owns widget IDs, placement, size and removal. Fri cannot move Android app icons itself. Use launcher drag/resize; available behavior varies by launcher.

## Scope

Included: local events, all-day ranges, ongoing/next selection, calendar filters, settings, presets, native pin/configure/reconfigure and refresh lifecycle. Stable Personal and Work calendars are created without sample events.

Not yet Android parity: Windows ICS/OCR intake, availability-file exchange, native desktop refraction, Spotify/maps/weather integrations, account/billing, Day. Android has opaque Fri surfaces; Android launchers control widget backgrounds and system blur. The desktop app retains its native glass implementation and integrations.

No publishing or account setup is performed by these scripts. Do not delete user app storage to test an upgrade.

## First-plan update

0.4.0/code 4 uses the shared `25cc294` recognition baseline, including relative-time invitations, an optional sample, progressive editor details and the naive Fri identity. See `../docs/first-plan-release.md` for observed checks. Background cross-app monitoring is still desktop-only.

0.4.1/code 5 adds Be Vietnam Pro, charcoal dark surfaces, brighter control borders and correct on-accent calendar text. See `../docs/appearance-081.md`. The native widget editor uses the same color roles; launcher widget text keeps the supported system family.


0.4.2/code 6 adds hour/minute/AM-PM wheels, one Confirm action, unsaved-edit protection on Back, and duration-preserving start changes. See `../docs/keyboard-and-time-082.md`.
