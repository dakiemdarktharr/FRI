#if os(macOS)
import FRIDesign
import SwiftUI

struct FRIUsageGuide: View {
    static let completionKey = "fri.usageGuideCompleted"
    static var defaults: UserDefaults {
        #if DEBUG
        if let profile = ProcessInfo.processInfo.environment["FRI_GUIDE_TEST_PROFILE"],
           let id = UUID(uuidString: profile), let store = UserDefaults(suiteName: "FRI.GuideTests." + id.uuidString) {
            return store
        }
        #endif
        return .standard
    }

    let reviewing: Bool
    let finish: () -> Void
    @State private var page = 0

    private struct Chapter {
        let icon: String
        let title: String
        let steps: [(String, String)]
    }

    private let chapters = [
        Chapter(icon: "calendar.badge.plus", title: "Tạo lịch trình đầu tiên", steps: [
            ("Mở lịch mới", "Trong lịch FRI, vào File → New Schedule hoặc nhấn ⌘N."),
            ("Điền cuộc hẹn", "Ví dụ, nhập “Cà phê với An” vào Name. Ở Date chọn ngày mai, ở Time nhập 09:00 và ở Duration nhập 30 phút. Bạn có thể thêm quán cà phê vào Location."),
            ("Lưu và kiểm tra", "Bấm Done. Nếu FRI hỏi thêm giờ hoặc thời lượng, điền thông tin và xác nhận. Mở ngày vừa chọn trong lịch để xem hoặc sửa cuộc hẹn.")
        ]),
        Chapter(icon: "bubble.left.and.bubble.right", title: "Kết nối ứng dụng chat", steps: [
            ("Mở cuộc trò chuyện", "Mở Zalo hoặc Messenger trên Mac, rồi vào File → Thư ký lịch… trong FRI."),
            ("Chọn nguồn được đọc", "Bấm Cho phép chọn cửa sổ chat… và cấp quyền Ghi màn hình cho FRI nếu macOS yêu cầu. Quay lại, bấm Làm mới danh sách cửa sổ rồi chọn Ghi nhớ ứng dụng Zalo hoặc Messenger."),
            ("Dùng thử khi đang chat", "Quay lại cửa sổ đã chọn. Trong Zalo, thử gõ “Mai 9h gặp ở quán cà phê nhé?” rồi dừng trước khi gửi. Khi FRI gợi ý, bấm Xem và lưu để chỉnh lịch hoặc Bỏ qua để tiếp tục chat.")
        ]),
        Chapter(icon: "globe", title: "Kết nối trang web", steps: [
            ("Mở trang chat", "Mở chat.zalo.me hoặc messenger.com trong Chrome hoặc Safari. Trang tin nhắn của Facebook cũng được hỗ trợ. Để tab chat ở phía trước khi dùng."),
            ("Ghi nhớ đúng trang", "Vào File → Thư ký lịch…, bấm Làm mới danh sách cửa sổ rồi chọn Nhớ trang cho dịch vụ và trình duyệt đang dùng. Nếu macOS hỏi quyền Tự động hóa, quyền này giúp FRI kiểm tra đúng địa chỉ tab. Bạn cũng có thể chọn riêng một cửa sổ."),
            ("Chủ động bật hoặc dừng", "FRI xử lý vùng chat trên máy khi bạn đang xem nguồn đã chọn. Đóng cửa sổ lịch để tiếp tục chạy nền. Mở biểu tượng lịch trên thanh menu để tạm dừng. Bạn có thể mở lại hướng dẫn bằng nút hình cuốn sách trong lịch.")
        ])
    ]

    var body: some View {
        let chapter = chapters[page]
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Hướng dẫn FRI", systemImage: "book")
                Spacer()
                Text("Phần \(page + 1) / \(chapters.count)").monospacedDigit()
                if reviewing {
                    Button("Đóng", action: finish).accessibilityIdentifier("fri.guide.close")
                }
            }.friFont(.subheadline, weight: .medium).padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: chapter.icon)
                        .font(.system(size: 32)).foregroundStyle(FRIColors.accent).accessibilityHidden(true)
                    Text(chapter.title).friFont(.title, weight: .bold)
                        .accessibilityAddTraits(.isHeader).accessibilityIdentifier("fri.guide.title")
                    ForEach(chapter.steps.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(chapter.steps[index].0).friFont(.headline)
                            Text(chapter.steps[index].1).friFont(.body).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Divider()
                    HStack {
                        if page > 0 {
                            Button("Quay lại") { page -= 1 }.accessibilityIdentifier("fri.guide.back")
                        }
                        Spacer()
                        if page == chapters.count - 1 {
                            Button(reviewing ? "Xong" : "Đã đọc · Vào FRI", action: finish)
                                .buttonStyle(.borderedProminent).accessibilityIdentifier("fri.guide.finish")
                        } else {
                            Button("Tiếp tục") { page += 1 }
                                .buttonStyle(.borderedProminent).accessibilityIdentifier("fri.guide.next")
                        }
                    }.controlSize(.large)
                }.padding(28).frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
            }.id(page)
        }
        .frame(minWidth: 450, minHeight: 400)
        .background(FRIColors.cloud).foregroundStyle(FRIColors.ink).tint(FRIColors.accent)
    }
}
#endif
