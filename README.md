# Fri

Fri gom lịch từ ảnh, văn bản và liên kết vào một nơi. Bạn xem bằng chứng, xác nhận thông tin rồi xếp việc quanh lịch hẹn, hạn nộp và thời gian di chuyển. Repo này chứa lát cắt **Web V1** cho desktop và mobile.

## Chạy ứng dụng

Mở `index.html` trong trình duyệt hiện đại. HTML, CSS, JavaScript và ảnh dữ liệu mẫu nằm trong cùng tệp. Ứng dụng dùng `localStorage` trên trình duyệt hiện tại. Để sử dụng một địa chỉ lưu trữ ổn định và thử nguồn công khai, chạy từ thư mục repo:

```powershell
python -m http.server 8000 --bind 127.0.0.1
```

Mở [Fri trên máy](http://127.0.0.1:8000/). Lịch minh họa bắt đầu ở thứ Hai 23/11/2026, múi giờ `Asia/Ho_Chi_Minh`. Chọn **Cài đặt → Quản lý dữ liệu → Lịch trống** để dùng lịch của bạn.

## Thử một lượt

1. Chọn **Thêm nguồn → Dùng dữ liệu mẫu**. Hai ảnh tổng hợp, một lịch ICS và một link yêu cầu đăng nhập đi qua cùng hàng đợi. Mở **Nguồn** để thử lại từng mục hoặc dán nội dung thay thế.
2. Trong **Cần duyệt**, xem ảnh và câu gốc “mai 7h”. Điền ngày, giờ đã biết rồi xác nhận, hoặc để mục lại để duyệt sau. Những mục đủ dữ kiện có thể xác nhận theo nhóm. Khi ICS đổi giờ, xem dữ liệu trước và sau, rồi chọn cách xử lý cùng với các chỉnh sửa cá nhân.
3. Mở **Lịch** và chuyển giữa **Ngày**, **Tuần**, **Tháng** và **Danh sách**. Chọn **Xếp việc** để xem khung giờ đề xuất và lý do, rồi áp dụng hoặc quay lại. Sửa, khóa, đánh dấu hoàn thành và hoàn tác có thể thực hiện ngay trong lịch.
4. Trong **Cài đặt**, thử 10 bảng màu, chế độ Sáng/Tối/Theo hệ thống và tùy chọn giảm trong suốt. **Widget** dùng dữ liệu cùng revision với lịch, có bản xem trước iPhone nhỏ/vừa, màn hình khóa và macOS. Chạm một thẻ để mở mục lịch tương ứng.

## Kiểm thử

Ứng dụng không cần cài gói. Bộ kiểm thử dùng Node.js và Playwright, tự mở máy chủ HTTP cục bộ khi chạy:

```powershell
npm ci --prefix tests
npm exec --prefix tests -- playwright install chromium webkit
npm test --prefix tests
$env:FRI_BROWSER = 'webkit'
npm run test:browser --prefix tests
Remove-Item Env:FRI_BROWSER
```

`npm run test:domain --prefix tests` chạy riêng các phép kiểm ngày giờ, trùng lịch, khung có mặt, hoạt động con, thiếu thời gian, revision và bản xem trước nhắc. Bộ kiểm thử trình duyệt bao gồm thao tác nhập nguồn, duyệt, lưu lại, đổi giao diện, xếp việc và điều hướng trên desktop/mobile.

Đã chạy thành công **12 kiểm thử logic, 12 kiểm thử Chromium và 12 kiểm thử WebKit** trên Windows. Bộ kiểm thử trình duyệt xác minh luồng một nguồn lỗi vẫn giữ phần đã đọc, nhập ảnh khi ngoại tuyến, cập nhật ICS giữ chỉnh sửa, chặn kế hoạch cũ từ tab khác, hoàn tác và xuất ICS. Đã kiểm tra điều hướng bằng bàn phím, màn hình 360 px, đổi màu qua reload và mở lại mục lịch qua đường dẫn widget.

## Phạm vi Web V1

- Nhập tệp ICS, nội dung dán và link ICS hoặc trang có sự kiện JSON-LD nếu máy chủ nguồn cho phép trình duyệt đọc. Ảnh người dùng chọn có xem trước cục bộ và đi qua bước nhập tay. Ảnh mẫu dùng câu trích xuất dựng sẵn.
- Bộ xếp việc dùng một ngày, một khung liên tục mỗi việc, theo giờ Việt Nam. Kế hoạch có kiểm tra revision trước khi áp dụng, giữ giờ nghỉ và phiên khóa. Tệp ICS xuất từ các phiên Fri đã xếp qua kiểm tra lại xung đột.
- Kết nối OAuth, OCR, đọc trang cần đăng nhập, mở rộng chuỗi ICS lặp, đồng bộ thiết bị và nhắc nền thuộc các mốc sau. Widget là bản xem trước Web. Kiểm thử trên thiết bị iOS và macOS thật thuộc mốc WidgetKit.

Thiết kế lấy Lake · Sun làm mặc định, dùng vật liệu kính cho vùng điều hướng và nền rõ hơn ở lịch, biểu mẫu và bằng chứng. Thẻ widget ưu tiên việc sắp tới, giờ rời đi và tiến độ. [Apple HIG — Materials](https://developer.apple.com/design/human-interface-guidelines/materials) · [Apple HIG — Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets)
