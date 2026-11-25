# FRI 0.7.0 build 4 · Hướng dẫn thiết kế và dựng lại

**Mốc mã nguồn** `3b48df283eb408fcebd4315ab0fdbd07608ecfab`. Build 4 là số build của target macOS `FRIMac`. Khi bàn giao hoặc so sánh kết quả giữa các máy, dùng commit này. Tag `v0.7.0` trỏ tới một mốc cũ hơn.

```sh
git clone https://github.com/dakiemdarktharr/FRI.git
cd FRI
git worktree add --detach ../FRI-build4 3b48df283eb408fcebd4315ab0fdbd07608ecfab
cd ../FRI-build4
```

| Nền tảng | Chạy được từ commit này | Phần cần phát triển để đạt hành vi như Mac |
|---|---|---|
| macOS native 0.7.0 (4) | Nhận lời chốt mới trong cửa sổ Zalo/Messenger đã chọn. Riêng Zalo có gợi ý ngay trong ô soạn | Là bản tham chiếu. Người phụ trách Apple trong dự án quản lý macOS và iOS |
| Windows và Linux, Electron 0.7.0 | Chọn cửa sổ, OCR tiếng Việt cục bộ, nhận lời chốt mới, mở biểu mẫu lịch | Đọc riêng ô soạn Zalo, theo dõi cửa sổ đang hoạt động và hiện gợi ý mà vẫn giữ con trỏ trong chat |
| Android 0.2.0 alpha, `versionCode 2` | Lịch cá nhân, sửa sự kiện và widget từ Expo/Kotlin/Room | Chưa có Thư ký lịch. Các bước port ở mục Android là thiết kế đề xuất |

## 1. Trải nghiệm cần tái tạo

Người dùng mở **File → Thư ký lịch…**, chọn cửa sổ chat, rồi tiếp tục nhắn bình thường. Trên Mac, khi ô soạn Zalo hiện *“ê xíu 9h trạm k”*, một bảng nhỏ ở góc trên bên phải hỏi **“Bạn có muốn lên lịch hẹn này?”**. Bảng hiển thị **Cuộc hẹn · trạm**, **Chưa rõ ngày** và **9h (sáng hay tối?)**. Người dùng vẫn gõ được khi bảng xuất hiện.

- **Bỏ qua** đóng bảng. Nội dung có cùng các trường lịch sẽ không lập tức làm bảng hiện lại. Sửa giờ hoặc địa điểm có thể tạo gợi ý mới. Xóa bản nháp thì gợi ý đang soạn được rút lại.
- **Xem và lưu** mở bản nháp lịch để người dùng bổ sung thông tin. Cuộc hẹn chỉ xuất hiện trong lịch sau bước lưu tại trình sửa. Giữ trống ngày, giờ chưa rõ. Với câu trên, giữ ghi chú giờ cần xác nhận và địa điểm nguyên văn.
- **Tin đã gửi** dùng một luồng khác. Ví dụ, bên kia hỏi *“Thứ sáu 19:00 họp nhé?”* rồi người dùng trả lời *“Ok, mình đi”*. FRI đối chiếu hai dòng mới có liên quan và gợi ý lịch họp.
- **Giới hạn của build 4.** *“ê xíu trạm k”* thiếu ngày hoặc giờ cụ thể nên cho kết quả rỗng. Gửi một câu rủ trước khi FRI kịp đọc ô soạn cũng có thể làm mất gợi ý. Khi mở lại cửa sổ, khung đầu tiên là mốc đối chiếu lịch sử.

**Bố cục.** Bảng Mac dùng `NSPanel` nổi 340 × 140 pt, không lấy tiêu điểm. Thứ tự đọc là câu hỏi, tên và địa điểm, ngày và giờ, rồi hai nút. Chuyển sang kích thước logic theo DPI khi làm trên Windows/Linux. Giữ chữ và nút tương phản ở cả hai giao diện sáng và tối. Dùng bảng màu của phần lịch với nền Cloud `#F4F7FA`, chữ Ink `#172B3A`, điểm nhấn Teal `#087F8C`. Thẻ lịch và các nút có nền đặc. Lịch chính nhóm sự kiện theo ngày và có các chế độ tuần, tháng, năm. [Thiết kế Cloud/Ink/Teal](cloud-feed-redesign.md) · [Guidebook giao diện](fri_design_guidebook.pdf)

## 2. Luồng xử lý và hợp đồng dữ liệu

| Bước | Mã tham chiếu | Trách nhiệm |
|---|---|---|
| Chọn nguồn | [FRIMeetingAgent.swift](../apple/FRI/FRIMeetingAgent.swift), [meeting-agent.cjs](../desktop/meeting-agent.cjs) | Gắn phiên với cửa sổ được chọn. Kiểm tra lại nguồn trước khi công bố kết quả OCR. Dọn tác vụ khi quyền hoặc nguồn hết hiệu lực |
| Lấy chữ | [MeetingOCR.swift](../apple/Packages/FRICore/Sources/FRICore/MeetingOCR.swift), [meeting-view.js](../desktop/meeting-view.js), [meeting-ocr.cjs](../desktop/meeting-ocr.cjs) | Cắt vùng cần đọc, so sánh với ảnh trước, chỉ chạy OCR khi vùng thay đổi |
| Hiểu lời hẹn | [meeting-agent.js](../apple/Packages/FRICore/Sources/FRICore/Resources/meeting-agent.js), [cầu nối Swift](../apple/Packages/FRICore/Sources/FRICore/MeetingRecognition.swift) | Một bộ luật JS chạy tại chỗ. Electron lấy bản sao qua `prepare:ui`. Chỉnh quy tắc ở file nguồn |
| Xem lại và lưu | [Lịch desktop](../preview/app.js), [IPC desktop](../desktop/preload.cjs), [trình sửa Android](../mobile/src/app/edit.tsx) | Truyền các trường của gợi ý vào trình sửa. Người dùng xác nhận rồi mới ghi lịch trên thiết bị |

Mỗi nguồn có trạng thái nhận diện riêng. Gọi `draft(text, now)` cho **chữ trong ô soạn của người dùng**. Gọi `observe(rows, now)` với các dòng chat theo thứ tự trên xuống, mỗi dòng có `text` và `side` bằng `own`, `other` hoặc `unknown`. Có thể truyền thời điểm tính bằng mili giây để kiểm thử các từ “mai”, “thứ sáu” theo ngày địa phương. Khi chuyển nguồn hoặc mất tính liên tục, thiết lập lại mốc hội thoại. Đọc được một lời hẹn trên màn hình chưa đủ để coi đó là tin mới.

```js
const { MeetingFrames } = require('./apple/Packages/FRICore/Sources/FRICore/Resources/meeting-agent.js');
const source = new MeetingFrames();
const now = new Date(2026, 10, 25, 10).getTime();
source.draft('ê xíu 9h trạm k', now);
// { title: 'Cuộc hẹn', date: null, time: null, location: 'trạm', timeHint: '9h' }
const question = { side: 'other', text: 'Thứ sáu 19:00 họp nhé?' };
source.observe([question], now); // null
source.observe([question, { side: 'own', text: 'Ok, mình đi' }], now);
// { title: 'Họp', date: '2026-11-27', time: '19:00' }
```

**Thu ảnh trên Mac.** ScreenCaptureKit lấy hình cửa sổ đã chọn khi nó ở phía trước. Vùng hội thoại bắt đầu ở 25% chiều rộng, 18% chiều cao và chiếm 74% × 68% ảnh. Ô soạn Zalo có vùng riêng sát đáy, bắt đầu ở 22% chiều rộng, rộng 55%, cao bằng giá trị nhỏ hơn giữa 6,8% chiều cao và 3,9% chiều rộng. Hai vùng có dấu ảnh riêng để phát hiện thay đổi khi người dùng chỉ gõ chữ. Vision xử lý ô soạn trước. Vòng lặp nghỉ khoảng 280 ms khi nguồn đang hoạt động và 600 ms khi đang chờ. Đây là thời gian nghỉ giữa các lượt, chưa gồm thời gian chụp và OCR.

**Dữ liệu riêng tư.** Hình cửa sổ có thể chứa cả chữ ngoài lời hẹn. Xử lý ảnh và các dòng OCR trong bộ nhớ, chỉ đưa trường lịch ra khỏi bộ nhận diện. Bộ lọc nhận diện một số dấu hiệu như OTP, mật khẩu hoặc thanh toán. Nội dung nhạy cảm khác vẫn có thể lọt qua bộ lọc. Thư ký lịch hoạt động offline, không cần khóa API, âm thanh hay bộ ghi bàn phím. Phần cài đặt phải cho thấy nguồn nào đang bật và có chỗ dừng phiên. [Quyền riêng tư theo tính năng](privacy.md)

## 3. Dựng Windows và Linux

Dùng Node.js 24 như workflow desktop, npm và các lockfile trong repo. Chạy khối sau từ thư mục gốc. Nếu sửa giao diện, sửa trong `preview/` rồi tạo lại HTML trước bước chuẩn bị Electron.

```sh
npm ci --prefix preview
npm run build --prefix preview
npm ci --prefix tests
npm exec --prefix tests -- playwright install chromium
npm ci --prefix desktop
node desktop/node_modules/electron/install.js
npm run prepare:ui --prefix desktop
npm test --prefix desktop
```

Để mở ứng dụng, chạy `npm start --prefix desktop`. Trong **Thư ký lịch**, bấm **Tìm cửa sổ**, chọn Zalo/Messenger rồi **Bật nhận diện**. Test Electron có giao diện cần phiên desktop đồ họa. Trên Linux, kiểm tra riêng phiên X11 và phiên Wayland có PipeWire cùng `xdg-desktop-portal` phù hợp với desktop đang dùng.

| Máy dựng | Lệnh từ thư mục gốc | Sản phẩm |
|---|---|---|
| Windows x64 | `npm run dist --prefix desktop`, sau đó `node desktop/verify-package.cjs` | `dist/FRI-0.7.0-win-x64.exe` (NSIS) và thư mục `dist/win-unpacked/` |
| Linux x64 | `cd desktop`, rồi `npx --no-install electron-builder --linux tar.gz --x64 --publish never` | `../dist/FRI-0.7.0-linux-x64.tar.gz` và `../dist/linux-unpacked/`. Chạy `node verify-package.cjs ../dist/linux-unpacked/resources/app.asar` từ `desktop/` |

**Kiểm tra gói đã đóng.** Trong `resources/app.asar` cần có `ui/meeting-agent.js`, `meeting-agent.html`, `meeting-view.js` và các module IPC/OCR. Trong `resources/app.asar.unpacked/node_modules/@tesseract.js-data/vie/4.0.0_best_int/` cần có `vie.traineddata.gz`. Kiểm tra trên máy đích với mạng đã tắt sau khi cài. Phiên Electron dùng Tesseract tiếng Việt đóng gói sẵn, yêu cầu video khoảng 2 khung/giây và nghỉ 500 ms giữa các lượt xử lý. [Cấu hình gói](../desktop/package.json) · [Workflow Windows](../.github/workflows/desktop.yml)

**Các bước port gợi ý trước khi gửi trên Windows/Linux**

1. Trong `meeting-view.js`, thêm vùng ô soạn Zalo với dấu ảnh riêng. Chuẩn hóa tọa độ theo ảnh chụp thực tế ở mức zoom và DPI khác nhau. Giữ vùng danh sách hội thoại, thanh bên và thanh công cụ ngoài ô soạn.
2. Mở rộng `meeting-preload.cjs` và `meeting-agent.cjs` để nhận biết khung ô soạn và khung hội thoại. Mỗi phiên có token riêng. Kiểm tra token, loại nguồn, kích thước và hiệu lực nguồn cả trước lẫn sau OCR. Trên Windows/X11, bổ sung bước xác minh cửa sổ đã chọn đang ở phía trước. Với Wayland, giữ phạm vi của luồng người dùng chọn qua portal, dừng khi track kết thúc, và thử hành vi khi chuyển cửa sổ trên compositor đích.
3. Dùng `MeetingFrames.draft` cho ô soạn. Hiện một bảng gợi ý không cướp tiêu điểm, thay nội dung khi lời hẹn đổi và thu hồi khi xóa nháp. Truyền cả `timeHint` sang trình sửa khi giờ còn mơ hồ. Luồng desktop hiện tại dùng `dialog.showMessageBox` cho lời chốt và `fri:meeting-review` để mở biểu mẫu.
4. Với nhiều nguồn, dừng hoặc bỏ kết quả OCR của đúng token vừa hết hiệu lực. Trên Wayland, build này chỉ giữ một luồng portal trong phiên. Tùy chọn mở cùng hệ thống là riêng biệt với quyền đọc cửa sổ.

## 4. Dựng Android và triển khai Thư ký lịch

Nền Android trong repo dùng Expo SDK 58, React Native 0.88.1 và module Kotlin `FriAndroid`. Chuẩn bị JDK 21, Android SDK platform `platforms;android-37.0`, Build Tools 37.0.0, NDK 27.1.12297006, CMake 3.22.1 và platform-tools. Đặt `JAVA_HOME`, `ANDROID_HOME` theo thư mục cài trên máy và chấp nhận giấy phép SDK. [Thiết lập Android và đường dẫn ngắn cho Windows](../mobile/README.md)

```sh
cd mobile
npm ci
npm run typecheck
npm run lint
npx --no-install expo prebuild --platform android --no-install --no-clean
```

Chạy một trong hai lệnh sau từ `mobile/`. Dùng `x86_64` thay `arm64-v8a` khi cần APK cho emulator x86_64.

```sh
# Linux hoặc macOS
NODE_ENV=production ./android/gradlew -p android :app:assembleRelease :fri-android:testDebugUnitTest -PreactNativeArchitectures=arm64-v8a --no-daemon --max-workers=2
```

```powershell
# Windows PowerShell
$env:NODE_ENV = 'production'
.\android\gradlew.bat -p android :app:assembleRelease :fri-android:testDebugUnitTest -PreactNativeArchitectures=arm64-v8a --no-daemon --max-workers=2
```

APK ở `android/app/build/outputs/apk/release/app-release.apk` tính từ `mobile/`. Cài trên thiết bị thử bằng `adb install -r android/app/build/outputs/apk/release/app-release.apk` khi chữ ký tương thích. Alpha dùng khóa debug của dự án Android sinh ra. Giữ các thay đổi native có thể tái tạo trong `modules/fri-android/` và `plugins/with-fri.cjs`. [Kiến trúc Android](../mobile/docs/architecture.md) · [Thiết bị Android đã kiểm tra cho bản alpha](../mobile/docs/verification.md)

**Thiết kế port cho chế độ tự gợi ý.** Trên Android 14+, người dùng chủ động bắt đầu phiên và chọn chia sẻ một ứng dụng qua MediaProjection. Chỉ bắt đầu nhận diện sau khi có quyền cho phiên đó. Khai báo foreground service loại `mediaProjection` và quyền tương ứng, hiển thị trạng thái đang chia sẻ, giải phóng virtual display/buffer khi `onStop` hoặc khi nội dung bị ẩn. Nếu người dùng chọn cả màn hình hoặc thiết bị không cung cấp phạm vi chia sẻ phù hợp, kết thúc phiên hoặc dùng phương án chia sẻ văn bản. Mỗi phiên MediaProjection cần sự đồng ý của người dùng. Hiển thị bước này khi khởi động phiên. [Android MediaProjection](https://developer.android.com/media/grow/media-projection)

- **OCR và suy luận.** Đóng gói model OCR tiếng Việt trên thiết bị, thử trực tiếp với bộ ảnh mẫu. Nối các dòng đã phân vai vào cùng hợp đồng `draft/observe`. Hiệu chỉnh vùng ô soạn khi bàn phím mở/đóng, ứng dụng xoay ngang hay đổi cỡ chữ.
- **Trình bày.** Dùng thông báo cho gợi ý khi được phép, chạm để mở bản nháp trong FRI. Khi quyền thông báo bị từ chối, dùng màn hình xem lại trong ứng dụng. Giữ riêng quyền thu hình, quyền thông báo và thao tác lưu lịch. [Quyền thông báo Android](https://developer.android.com/develop/ui/compose/notifications/notification-permission)
- **Chia sẻ một lời hẹn.** Hỗ trợ `ACTION_SEND` với `text/plain` để người dùng chủ động chia sẻ một lời hẹn trên thiết bị cũ hoặc khi không mở phiên thu hình. [Nhận nội dung được chia sẻ](https://developer.android.com/develop/ui/compose/sharing/receive)
- **Ghi lịch.** Giữ dữ liệu đề xuất trong bộ nhớ đến bước xem lại. Chuyển ngày, giờ, múi giờ và thời lượng đã xác nhận qua `call('saveEvent', payload)`. Với sự kiện có giờ, dùng `startLocal`, `endLocal`, `zone` hoặc các mốc UTC tương ứng. Repository ghi Room rồi cập nhật widget qua luồng hiện có. [Cầu nối TypeScript](../mobile/src/lib/fri.ts) · [FriRepository.kt](../mobile/modules/fri-android/android/src/main/java/expo/modules/friandroid/FriRepository.kt)

## 5. Nghiệm thu bản dựng và bản port

| Tình huống | Kết quả mong đợi theo build 4 |
|---|---|
| Ô soạn Zalo có “ê xíu 9h trạm k” | Trên Mac và bản port đã có ô soạn: một bảng gợi ý, giữ con trỏ, địa điểm “trạm”, ngày và giờ chuẩn còn trống |
| Người dùng gõ “ê xíu trạm k”, hoặc chỉ “9h” | Bộ nhận diện build 4 trả về `null` |
| Hai dòng hỏi và chốt trong ví dụ JS | Gợi ý “Họp”, ngày 27/11/2026, 19:00 với đồng hồ kiểm thử đã cho |
| Mở lại cùng hội thoại, đổi sang cửa sổ khác, thu hồi quyền hoặc tắt phiên trong lúc OCR đang chạy | Lịch sử không tạo hàng loạt gợi ý. Kết quả của nguồn hết hiệu lực bị bỏ. Calendar không bị ghi ngầm |
| Bỏ qua, gõ tiếp, xóa nháp, rồi chọn Xem và lưu với một lời hẹn mới | Không lặp gợi ý vừa bỏ qua vì con trỏ nháy. Trình sửa cho phép bổ sung trường còn thiếu và chỉ tạo sự kiện sau xác nhận |
| Lời hủy, câu có mật khẩu/OTP hoặc dòng không xác định được người nói | Các ví dụ loại trừ trong bộ test trả về `null`; dùng dữ liệu giả khi kiểm thử |
| Tắt mạng trên thiết bị thử | Chọn nguồn, OCR, nhận diện và lưu lịch vẫn chạy với các thành phần đã đóng gói |

Test có sẵn gồm [quy tắc, OCR và IPC Electron](../desktop/meeting-agent.test.cjs), [Vision từ ảnh mẫu](../apple/Packages/FRICore/Tests/FRICoreTests/MeetingRecognitionTests.swift) và [vòng đời bảng gợi ý trên Mac](../apple/MacTests/FRIMeetingAgentTests.swift). Để chạy riêng bộ Electron từ thư mục gốc sau khi cài phụ thuộc, dùng `node --test desktop/meeting-agent.test.cjs`.

**Đo độ trễ.** Ghi riêng thời điểm ký tự cuối hiển thị, lúc bắt đầu lấy hình và lúc bảng hiện. Lần đo Zalo Web trên Mac với câu đã gõ sẵn cho kết quả **1,91 giây** từ khi đưa cửa sổ ra trước và **68 ms** từ lần lấy hình tạo ra gợi ý đến lúc bảng hiện. Chưa có số đo từ phím cuối ở lần đó. Với bản port, báo trung vị và p95 trên nhiều lần gõ, kèm OS, DPI, ứng dụng chat và trạng thái OCR nóng/lạnh.

**Đối chiếu bản Mac.** Dùng target `FRIMac`, cấu hình Release standalone trong [Xcode project](../apple/FRI.xcodeproj/project.pbxproj). Từ thư mục gốc trên Mac Apple Silicon.

```sh
xcodebuild -project apple/FRI.xcodeproj -scheme FRIMac -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/fri-build4.noindex \
  CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= build
swift test --package-path apple/Packages/FRICore
```

Sản phẩm là `/tmp/fri-build4.noindex/Build/Products/Release/FRIMac.app`. Kiểm tra `CFBundleShortVersionString=0.7.0`, `CFBundleVersion=4` và `FRIStorageMode=standalone`. SHA-256 của file `meeting-agent.js` trong app tham chiếu là `478a7819b7049e1b5cbbbde6009461339de1a11e54a78e4fb60a67e14fc391a4`. Khi dùng chữ ký ad-hoc, macOS có thể yêu cầu cấp lại quyền Ghi màn hình sau khi thay binary.

### Kết quả kiểm tra khi bàn giao

- **Mac.** Rebuild Release bằng Xcode 27.2 trên Apple Silicon. Vùng mã máy `__TEXT,__text` của chương trình chính và file quy tắc JS khớp từng byte với app build 4 đã lưu. Các bài thử Swift và hai bài thử chạy trong ứng dụng Mac đều đạt.
- **Desktop.** Đã đóng gói NSIS x64 cho Windows và tar.gz x64 cho Linux từ Mac. Trong cả hai gói, đã đối chiếu SHA-256 của bộ luật và chạy bộ OCR đóng gói với hai ảnh hội thoại mẫu. Bộ Electron đạt 78/78 trên Mac ở lượt chạy lại. Lượt đầu hết thời gian chờ nút Done trong một bài thử giao diện. Việc cấp quyền, giữ tiêu điểm và cửa sổ Zalo thực tế trên Windows/X11/Wayland vẫn cần nghiệm thu trên hệ điều hành đích.
- **Android.** Đã cài phụ thuộc từ lockfile, kiểm tra TypeScript, lint và sinh thành công dự án Android bằng Expo prebuild. Lượt bàn giao này dừng trước Gradle assemble và kiểm thử trên thiết bị.
