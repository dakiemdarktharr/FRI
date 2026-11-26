# FRI 0.7.0 build 7 · Hướng dẫn sử dụng lần đầu

Build 7 thêm hướng dẫn tiếng Việt vào FRI native trên Mac và vào bản desktop Electron cho Windows và Linux. [Tải FRI cho Mac Apple Silicon](../artifacts/macos/FRI-0.7.0-build7-mac-arm64.zip).

## Người dùng sẽ thấy gì?

Lần đầu mở bản có hướng dẫn, FRI hiển thị ba phần trước màn hình lịch. Bấm **Tiếp tục** ở cuối mỗi phần. Ở cửa sổ nhỏ, cuộn xuống để xem các bước và nút. Phần cuối có nút **Đã đọc · Vào FRI**. Từ lần mở sau, FRI vào thẳng lịch. Người đang nâng cấp từ build 6 cũng xem hướng dẫn một lần.

| Phần | Thao tác người dùng học được |
|---|---|
| Tạo lịch trình đầu tiên | Mở **New → Schedule**, đặt “Cà phê với An” vào 09:00 ngày mai trong 30 phút, bấm **Done**, bổ sung thông tin nếu FRI hỏi và mở ngày đó để kiểm tra. Trên Mac có thể dùng **⌘N**. |
| Kết nối ứng dụng chat | Mở cuộc trò chuyện Zalo hoặc Messenger rồi vào **File → Thư ký lịch…**. Trên Mac, cấp quyền Ghi màn hình, làm mới danh sách và chọn ứng dụng. Trên Windows/Linux, chọn **Tìm cửa sổ**, chọn nguồn và bấm **Bật nhận diện**. |
| Kết nối trang web | Trên Mac, mở Zalo Web hoặc Messenger trong Chrome/Safari rồi chọn **Nhớ trang** cho dịch vụ tương ứng. macOS có thể hỏi quyền Tự động hóa để FRI kiểm tra địa chỉ tab. Trên Windows/Linux, mở trang chat trong cửa sổ riêng và chọn cửa sổ đó. |

Có thể **Quay lại** để xem phần trước. Thoát trước khi xác nhận thì lần mở tiếp theo bắt đầu ở phần đầu. Sau khi hoàn tất, bấm **nút hình cuốn sách** trên thanh công cụ lịch để đọc lại. Khi đọc lại, có thể bấm **Đóng** ở bất kỳ phần nào để trở về lịch đang xem. Việc đọc hướng dẫn và việc cấp quyền đọc chat là hai thao tác riêng.

Tính năng nhận diện đã có từ build trước. Trên Mac, FRI có thể gợi ý ngay trong lúc soạn trên Zalo. Bản Electron trên Windows/Linux nhận diện cuộc hẹn đã chốt trong cửa sổ được chọn. [Chi tiết cơ chế, phạm vi quyền và giới hạn thực tế](thu-ky-lich-0.7.0-build-6.md).

## Cách triển khai

- **macOS.** Cửa sổ SwiftUI kiểm tra giá trị `fri.usageGuideCompleted` trong UserDefaults trước khi hiển thị lịch. Trong lần đọc đầu, lệnh mở lịch bị khóa và liên kết đến lịch được giữ đến sau khi đọc xong. Nút cuốn sách dùng lại cùng giao diện dưới dạng bảng đọc lại. [Giao diện hướng dẫn](../apple/FRI/FRIUsageGuide.swift) · [Điểm mở ứng dụng](../apple/FRI/FRIApp.swift)
- **Windows/Linux.** Khi hồ sơ người dùng chưa có tệp `usage-guide-read`, tiến trình chính Electron nạp trang hướng dẫn cục bộ. Nút ở phần cuối yêu cầu tiến trình chính ghi dấu đã đọc trong thư mục `userData` rồi mở lịch. Nút sách mở cửa sổ con và giữ nguyên cửa sổ lịch bên dưới. Nội dung hướng dẫn nằm trong gói ứng dụng và đọc được ngoại tuyến. [Trang hướng dẫn](../desktop/usage-guide.html) · [Điều khiển các phần](../desktop/usage-guide.js) · [Luồng mở cửa sổ](../desktop/main.cjs)

## Dựng lại trên Windows x64 hoặc Linux x64

Dùng Git, Node.js 24 và npm. Chạy từ thư mục gốc của checkout chứa tài liệu này. Dùng PowerShell trên Windows hoặc terminal trên Linux. Các bước chuẩn bị giao diện và bộ nhận diện phải chạy trước khi đóng gói.

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

Chạy thử bằng `npm start --prefix desktop`. Kiểm thử giao diện cần phiên đồ họa. Trên Linux, nếu Chromium thiếu thư viện hệ thống, chạy `npm exec --prefix tests -- playwright install --with-deps chromium`. Để thử trên hồ sơ hoàn toàn mới mà vẫn giữ lịch thật, dùng bài kiểm thử riêng bên dưới từ thư mục gốc.

```sh
node --test --test-name-pattern="first run requires all guide chapters" desktop/desktop.test.cjs
```

**Windows x64**

```powershell
npm run dist --prefix desktop
node desktop/verify-package.cjs
```

Bộ cài NSIS nằm ở `dist/FRI-0.7.0-win-x64.exe`. Bản chạy trực tiếp nằm trong `dist/win-unpacked/`.

**Linux x64**

```sh
cd desktop
npx --no-install electron-builder --linux tar.gz --x64 --publish never
node verify-package.cjs ../dist/linux-unpacked/resources/app.asar
cd ..
tar -xzf dist/FRI-0.7.0-linux-x64.tar.gz -C dist
./dist/FRI-0.7.0-linux-x64/fri-desktop
```

Nếu dùng Wayland để chia sẻ cửa sổ chat, máy đích cần PipeWire và `xdg-desktop-portal` phù hợp với môi trường desktop. Hệ điều hành có thể yêu cầu chọn lại cửa sổ ở phiên sau.

## Kết quả của build này

| Hạng mục | Đã xác minh |
|---|---|
| macOS | Xcode 27.2 build Release cho Apple Silicon, phiên bản 0.7.0 (7). Đã cài vào Applications, mở hướng dẫn qua nút cuốn sách, kiểm tra chữ ký và đối chiếu file thực thi với bản ZIP. ZIP ký ad hoc để thử nội bộ. Khi cập nhật từ build 6, macOS có thể yêu cầu cấp lại quyền đọc chat. |
| Hướng dẫn và lịch trên Mac | 7/7 bài Xcode được chạy đạt. Bài mới dùng hồ sơ riêng, thử ⌘N khi chưa đọc xong, thoát ở phần 2, mở lại, đọc đến phần 3, quay lại, xác nhận, khởi động lại và mở lại bằng nút sách. 48 bài lõi và 13 bài thiết kế Swift cũng đạt. |
| Electron | 80/80 bài đạt trên máy dựng Mac, gồm lần đầu, thoát giữa chừng, lưu trạng thái qua lần mở sau và đọc lại bằng nút sách. |
| Gói Windows/Linux | Đã dựng chéo bộ cài NSIS Windows x64 và gói Linux x64 trên Mac. Cả hai qua kiểm tra ASAR, có tệp hướng dẫn và mô hình OCR tiếng Việt. Việc cài, chạy giao diện và xác nhận quyền trên Windows/Linux thật chưa được thử trong đợt này. |

SHA-256 của bản ZIP macOS trên GitHub là `b6399610c4b5a67ddc2fefccfd45cf6087783eddacc3000ba53883c437e5b6b1`.
