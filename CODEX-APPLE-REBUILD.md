# Rebuild Fri trên macOS và iOS

Đây là điểm bắt đầu cho Codex trên Mac. Mục tiêu là đưa **native SwiftUI app + widget** lên cùng thiết kế và hành vi với Windows **0.8.2**, Android **0.4.2**, commit tham chiếu `d31f0077745b85941b4fdd4e1bc3009de1e6a82b`. Bản native hiện có là macOS **0.7.0 build 7**; chỉ build lại source hiện tại sẽ chưa có đầy đủ thay đổi mới.

## Prompt để giao cho Codex trên Mac

> Đọc AGENTS.md áp dụng cho workspace, CODEX-APPLE-REBUILD.md và các tài liệu được liên kết bên dưới. Kiểm tra git status và commit mới nhất trước khi sửa; giữ mọi thay đổi đang có của người dùng. Phát triển tiếp native project apple/FRI.xcodeproj, không tạo lại app hoặc thay bằng WebView. Đối chiếu Windows 0.8.2 / Android 0.4.2 trong bộ handoff, triển khai mọi mục chưa đạt trong acceptance.json, kiểm thử app macOS và iOS Simulator cùng widget. Giữ tính năng native Apple đang mạnh hơn Windows, đặc biệt Thư ký lịch. Dùng palette Cloud/Ink/Teal, Be Vietnam Pro, naive symbols, main space có native glass và mọi card/control opaque. Form có wheel chọn giờ và một Confirm; thêm keyboard navigation, bảo vệ draft, xử lý focus và widget persistence theo contract. Không thêm Day/AI mới. Sau khi build/test thành công, tạo app/installer macOS và archive iOS phù hợp với signing hiện có, lưu bằng chứng vào receipt. Không gọi unsigned/ad-hoc build là bản notarized hoặc coi Simulator là kiểm chứng thiết bị thật. Cập nhật tài liệu và Obsidian nếu máy có vault; commit và push GitHub. Chỉ thay link tải Mac sau khi bản mới đã được kiểm chứng. Không đổi bundle ID/App Group/Keychain của bản đang cài, không xóa dữ liệu người dùng.

## Đọc theo thứ tự

1. [Kế hoạch port 0.8.2 theo từng file](docs/apple/10-082-REBUILD-PLAN.md): trạng thái thực tế, thay đổi bắt buộc, phần phải giữ.
2. [Build, test, installer và iOS archive](docs/apple/11-082-BUILD-RUNBOOK.md): lệnh chạy được, signing và cách ghi kết quả.
3. [Hành vi keyboard/time picker](docs/keyboard-and-time-082.md) và [thiết kế/onboarding](docs/apple/09-FIRST-PLAN-REBUILD.md).
4. [Dữ liệu và migration](docs/apple/02-ARCHITECTURE-DATA.md), [WidgetKit](docs/apple/04-WIDGETKIT.md), [privacy/integrations](docs/apple/06-INTEGRATIONS-PRIVACY.md).
5. [Acceptance cases](apple/Handoff/acceptance.json), [design tokens](apple/Handoff/design-tokens.json), [fixtures](apple/Handoff/interaction-fixtures.json), [ảnh đối chiếu](docs/apple/reference-082/README.md).

Các tài liệu 0.5/0.7 và verification cũ là lịch sử. Khi mâu thuẫn về giao diện, dùng contract 0.8.2; khi nói về tính năng native đã có, đọc source và giữ tính năng đó. Không coi ghi chú “Day deferred” cũ là yêu cầu xóa Day hiện có.

## Bắt đầu trên Mac

```sh
git fetch origin
git status --short
# Chọn branch dựa trên main mới nhất sau khi bảo toàn công việc local.
git switch -c codex/apple-082 origin/main
node apple/Tools/rebuild-handoff.cjs check
bash apple/Tools/rebuild-on-mac.sh doctor
node apple/Tools/rebuild-handoff.cjs receipt
```

Node 22+ và Python 3 dùng để kiểm tra/chuẩn bị; full Xcode + simulator runtime + XcodeGen dùng để build. Không cần OpenAI key để port giao diện và kiểm tra các fixture local. Các file ký mẫu nằm ở `apple/Handoff/Config/`; điền thông tin thật vào **apple/Config/Local.xcconfig** và các export plist local bị gitignore.

Font, logo, icon catalog, guidebook và mã tham chiếu đều đã nằm trong repo. Không cần lấy file từ ổ D: của máy Windows. [Asset catalog sẵn dùng](apple/Handoff/Assets.xcassets) là tài nguyên để tích hợp; nó chưa tự thay tài nguyên trong target Xcode. [Manifest](apple/Handoff/manifest.json) ghi checksum để phát hiện reference bị lệch.

**Phạm vi xác minh của bộ này:** kiểm tra file, checksum, fixture, asset generation và script trên Windows; các lệnh Xcode, signed WidgetKit, notarization và TestFlight cần chạy trên Mac. Xem [receipt của bộ handoff](docs/apple/12-082-HANDOFF-VERIFICATION.md).
