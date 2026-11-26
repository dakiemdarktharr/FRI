# FRI 0.7.0 build 6 · Thư ký lịch chạy nền

Build 6 dành cho ứng dụng macOS native, Apple Silicon, macOS 14 trở lên. Mã Windows/Linux nằm trong `desktop/` và dùng bộ nhận diện tiếng Việt chung. Người dùng phụ trách phát triển, tích hợp macOS và iOS trong dự án FRI.

[Tải bản Mac build 6 để thử nội bộ](../artifacts/macos/FRI-0.7.0-build6-mac-arm64.zip) · [Mã ứng dụng macOS](../apple/FRI/FRIMeetingAgent.swift) · [Mã trợ lý Electron](../desktop/meeting-agent.cjs)

## Dùng trên Mac

1. Mở FRI trong Applications. Chọn **File → Thư ký lịch…**. Bấm **Cho phép chọn cửa sổ chat…** và xác nhận quyền Ghi màn hình trong macOS. Nếu hệ thống yêu cầu mở lại ứng dụng, mở lại chính bản FRI này.
2. Mở Zalo, Messenger hoặc một cửa sổ riêng cho trang chat. Làm mới danh sách trong FRI rồi chọn phạm vi trong bảng dưới.
3. Bật **Mở FRI khi đăng nhập** nếu muốn FRI tự khởi động ở phiên đăng nhập tiếp theo. Khi macOS yêu cầu duyệt mục đăng nhập, duyệt FRI trong Cài đặt hệ thống.
4. Đóng cửa sổ lịch bằng nút đỏ hoặc ⌘W và quay lại chat. Biểu tượng lịch trên thanh menu cho phép mở lại lịch, **Tạm dừng nhận diện**, **Tiếp tục nhận diện** hoặc **Thoát FRI**. Tạm dừng giữ các nguồn đã chọn. **Quên các nguồn đã chọn** xóa các lựa chọn trong FRI. ⌘Q thoát tiến trình.

| Lựa chọn | FRI sẽ đọc lúc nào | Sau khi mở lại |
|---|---|---|
| **Ghi nhớ ứng dụng Zalo/Messenger** | Cửa sổ chat hợp lệ của ứng dụng đó đang ở phía trước. Lựa chọn bao gồm các cuộc trò chuyện trong ứng dụng. | FRI nhận lại ứng dụng theo mã định danh dù tiến trình hoặc cửa sổ đổi. Các quyền cửa sổ từ build cũ tiếp tục giữ phạm vi cũ cho tới khi người dùng chọn chế độ mới. |
| **Nhớ trang Zalo/Messenger Web · Chrome/Safari** | Tiêu đề cửa sổ phù hợp và địa chỉ tab thuộc đúng dịch vụ đã chọn. Với Facebook, chỉ nhận các đường dẫn tin nhắn được hỗ trợ. | Ghi nhớ dịch vụ theo từng trình duyệt. Lần thiết lập đầu, macOS có thể hỏi thêm quyền **Tự động hóa** để đọc địa chỉ tab. Màn hình thiết lập vẫn cho chọn riêng cửa sổ nếu từ chối. |
| **Chọn một cửa sổ trình duyệt** | Cửa sổ đang xem khớp trình duyệt, tiến trình, mã cửa sổ và tiêu đề đã chọn. | Mở lại FRI vẫn dùng được nguồn nếu cửa sổ còn nguyên. Khi trình duyệt tạo cửa sổ mới hoặc tiêu đề đổi, chọn lại nguồn. |

**Quyền trên máy.** FRI lưu lựa chọn và chỉ gọi hộp thoại cấp quyền từ thao tác thiết lập của người dùng. macOS quyết định khi nào phải xác nhận lại, kể cả khi thu hồi quyền, đổi bản ký hoặc theo chính sách của máy. ZIP trong repo ký ad hoc để thử nội bộ. Gatekeeper có thể chặn trên máy khác và quyền của bản trước có thể cần cấp lại. Bản phát cho người ngoài cần Developer ID ổn định, ký và notarize qua Apple. [Quyền ghi màn hình](https://support.apple.com/guide/mac-help/control-access-to-screen-and-system-audio-recording-mchld6aa7d23/mac) · [Mục đăng nhập của ứng dụng](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp)

## Thay đổi từ build 4

- Tiến trình giữ trợ lý sau khi đóng hết cửa sổ. Khi đăng nhập, FRI khôi phục các nguồn đã bật. Nút **Xem và lưu** đưa người dùng trở lại trình sửa lịch. Cuộc hẹn chỉ được ghi sau khi người dùng xác nhận.
- Zalo nhận lời rủ ngay trong ô soạn. Với “ê xíu trạm k”, FRI giữ địa điểm “trạm”, hiển thị “Lát nữa” và hỏi giờ cụ thể. Nếu người dùng gửi nhanh, tin mới từ phía người dùng còn có thể tạo gợi ý. Bỏ qua một gợi ý sẽ ngăn việc nhắc lại cùng lời rủ khi gửi. Với Messenger, luồng đã triển khai nhận lời chốt trong hội thoại.
- Chỉ những ứng dụng đã chọn mới kích hoạt việc kiểm tra cửa sổ. Khi người dùng chuyển sang ứng dụng khác, máy ngủ, màn hình ngủ hoặc phiên người dùng mất hoạt động, tác vụ lấy ảnh dừng. Khi quay lại, FRI đối chiếu lại nguồn và thiết lập lại mốc hội thoại.
- Ở cửa sổ chat đang thay đổi, khoảng nghỉ giữa hai lượt là 280 ms. Sau sáu khung ít biến động liên tiếp, khoảng nghỉ tăng lên 750 ms. Khi ứng dụng nguồn đang mở phía trước nhưng chưa có cửa sổ phù hợp, khoảng nghỉ là 1.100 ms. Khi sang ứng dụng ngoài danh sách, trợ lý chờ thông báo của macOS và không có vòng lấy ảnh. Các khoảng nghỉ chưa bao gồm thời gian lấy ảnh hoặc Vision chạy OCR.
- FRI giữ tối đa một lượt lấy ảnh/OCR đang xử lý. Dấu ảnh của vùng hội thoại và ô soạn được kiểm riêng. Chỉ vùng thay đổi đi qua OCR. FRI kiểm tra lại nguồn trước khi hiện kết quả và dừng hoạt ảnh lịch khi ứng dụng mất tiêu điểm. Tiến trình lịch vẫn thực hiện các công việc riêng như duy trì lời nhắc.
- Ảnh và chữ OCR của Thư ký lịch chỉ được xử lý trong bộ nhớ trên máy. Chế độ ghi nhớ trang dùng Apple Events chỉ để lấy địa chỉ tab trước của Chrome/Safari. Chỉ cặp trình duyệt–dịch vụ được lưu cho chế độ này. Dấu băm của địa chỉ dùng tạm để bỏ kết quả cũ khi đổi trang. Không gửi nội dung chat tới AI đám mây.

[Mã kiểm tra trang chat](../apple/FRI/FRIMeetingBrowser.swift) · [Bộ nhận diện dùng chung](../apple/Packages/FRICore/Sources/FRICore/Resources/meeting-agent.js) · [Kiểm thử macOS](../apple/MacTests/FRIMeetingAgentTests.swift)

## Dựng lại macOS native

Dùng Xcode với macOS SDK, Swift 6 và Metal toolchain. Các lệnh dưới đây chạy từ thư mục gốc của repo. Project Xcode đã được commit. Khi thay đổi danh sách file hoặc cài đặt target, sửa `apple/project.yml` và chạy `xcodegen generate --spec apple/project.yml` trước.

```sh
xcodebuild -project apple/FRI.xcodeproj -scheme FRIMac -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/fri-build6.noindex \
  CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO build
mkdir -p dist/native-macos
ditto /tmp/fri-build6.noindex/Build/Products/Release/FRIMac.app dist/native-macos/FRI.app
codesign --verify --deep --strict dist/native-macos/FRI.app
ditto -c -k --norsrc --noextattr --keepParent dist/native-macos/FRI.app \
  dist/native-macos/FRI-0.7.0-build6-mac-arm64.zip
```

## Dựng lại Windows và Linux

Cài Git, Node.js 24 và npm. Dùng shell thường hoặc PowerShell trên Windows x64. Trên Linux x64, dùng một phiên đồ họa để thực hiện kiểm thử Electron. Chạy từ cùng commit chứa tài liệu này. Các lockfile chọn phiên bản thư viện. Bước chuẩn bị giao diện chép đúng bộ luật mới vào gói desktop.

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

Nếu Chromium trên Linux báo thiếu thư viện hệ thống, dùng `npm exec --prefix tests -- playwright install --with-deps chromium` trên máy dựng. Để mở ứng dụng khi phát triển, chạy `npm start --prefix desktop`.

**Windows x64**

```powershell
npm run dist --prefix desktop
node desktop/verify-package.cjs
```

Bộ cài NSIS ở `dist/FRI-0.7.0-win-x64.exe`. Bản chạy trực tiếp nằm trong `dist/win-unpacked/`.

**Linux x64**

```sh
cd desktop
npx --no-install electron-builder --linux tar.gz --x64 --publish never
node verify-package.cjs ../dist/linux-unpacked/resources/app.asar
cd ..
```

Gói ở `dist/FRI-0.7.0-linux-x64.tar.gz`. Giải nén trên máy đích rồi chạy file `fri-desktop` trong thư mục đã giải nén. Bản unpack để thử ở `dist/linux-unpacked/`. Với Wayland, cần PipeWire cùng `xdg-desktop-portal` phù hợp desktop. Trình chọn của hệ điều hành có thể yêu cầu chọn cửa sổ lại ở phiên mới.

**Phạm vi của các bản dựng.** Electron đã có khay hệ thống, mở khi đăng nhập, chọn nguồn, OCR tiếng Việt ngoại tuyến và gợi ý khi cuộc hẹn đã chốt. Bộ luật JS mới đi cùng hai bản dựng. Phần điều phối nền bằng NSWorkspace, nhớ nguồn trang web qua Apple Events và đọc riêng ô soạn Zalo nằm trong ứng dụng Mac. Để port, nhóm Windows/Linux cần gắn vòng lấy ảnh với ứng dụng/cửa sổ đang hoạt động, kiểm quyền ngay trước và sau OCR, hủy tác vụ khi mất nguồn, tách ô soạn và hiện gợi ý mà vẫn giữ con trỏ trong chat. Kiểm riêng X11 và Wayland. [Thiết kế cổng desktop](thu-ky-lich-0.7.0-build-4.md) · [Kiểm tra bộ cài và mô hình OCR](../desktop/verify-package.cjs)

## Thử nghiệm thu

1. Chọn một nguồn, đóng cửa sổ FRI, chuyển qua ứng dụng khác rồi trở lại chat. Kiểm tra biểu tượng FRI và mức CPU của tiến trình trong Activity Monitor.
2. Trong Zalo thử gõ “ê xíu trạm k” rồi dừng trước khi gửi. Ghi thời gian từ ký tự cuối đến lúc gợi ý hiện. Bấm **Xem và lưu**, đặt giờ và thời lượng, mở lại FRI và kiểm tra chỉ có một sự kiện.
3. Trong Messenger thử một lời mời có ngày giờ, rồi xác nhận ở tin nhắn mới. Thử **Bỏ qua** một lần. Bấm **Tạm dừng** rồi thử câu khác. Sau **Tiếp tục**, nguồn đã chọn phải còn.
4. Đóng và mở lại trình duyệt ở chế độ **Nhớ trang**. Thử trang khác có chữ Zalo trong tiêu đề, rồi mở đúng trang chat. Thử thu hồi quyền. Chỉ đúng trang còn quyền mới được tạo gợi ý.

## Kết quả kiểm tra ngày 26/11/2026

| Kiểm tra | Kết quả |
|---|---|
| Native macOS Release | Xcode dựng được `FRIMac` bản 0.7.0 (6) arm64. Đã giải nén ZIP, kiểm tra chữ ký bằng `codesign --verify --deep --strict` và đối chiếu file thực thi với ứng dụng trong Applications. Bản ad hoc này bị Gatekeeper từ chối khi đánh giá phân phối. |
| Chạy nền và vòng đời | 6/6 bài Xcode trên Mac đạt. Bài giao diện đóng cửa sổ lịch cuối cùng, xác minh tiến trình còn chạy, mở Thư ký lịch, bỏ qua gợi ý mẫu rồi mở lại trình sửa lịch từ một gợi ý mới. Các bài khác kiểm tra tạm dừng/khôi phục nguồn, đúng tên miền, bản nháp lúc đang gõ và tránh nhắc hai lần sau khi gửi. |
| CPU và RAM | Lấy mẫu tiến trình FRI trong Applications mỗi giây trong 45,45 giây. CPU trung bình 0,46% của một lõi; RAM thường trú (RSS) trung vị 87,3 MiB. Có một nguồn được ghi nhớ. Quyền ghi màn hình cũ chưa khớp chữ ký bản mới nên phép đo này mô tả trạng thái chờ. |
| Nhận diện và lịch | 48 bài lõi Swift và 13 bài thiết kế đạt. Bài Vision dùng ảnh hội thoại mẫu đo 59 ms từ khung hình thay đổi tới kết quả đề xuất. Chưa đo độ trễ đầu cuối hay mức dùng CPU khi gõ trong hội thoại Zalo/Messenger thật của build 6. |
| Desktop Windows/Linux | 79/79 bài Electron và bộ luật dùng chung đạt trên máy dựng Mac. Đã đóng gói chéo Linux x64 bằng đúng lệnh trên, kiểm tra ASAR và mô hình OCR tiếng Việt. Chưa chạy gói này trong phiên Linux thật hay dựng lại bộ cài trên máy Windows trong lần này. |

SHA-256 của ZIP macOS kèm theo là `0969e5d7ce0204b329747f9805a34f1609d3ff9f1bb98f83756e1ec86e76e259`.
