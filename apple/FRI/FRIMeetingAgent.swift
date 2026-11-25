#if os(macOS)
import AppKit
import CryptoKit
import FRICore
import OSLog
import ScreenCaptureKit
import ServiceManagement
import SwiftUI
import Vision

struct MeetingWindow: Identifiable {
    let window: SCWindow
    let bundle: String
    let title: String
    let native: Bool
    var id: CGWindowID { window.windowID }
    var isZalo: Bool {
        bundle.hasPrefix("com.vng.zalo") || title.range(of: #"\bZalo\b"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func candidate(_ window: SCWindow) -> Self? {
        guard window.windowLayer == 0, let app = window.owningApplication,
              let title = window.title, !title.isEmpty, window.frame.width >= 360, window.frame.height >= 260 else { return nil }
        guard title.range(of: #"đăng nhập|mật khẩu|xác thực|thanh toán|password|sign in|login|payment|verification"#,
                          options: [.regularExpression, .caseInsensitive]) == nil else { return nil }
        let bundle = app.bundleIdentifier.lowercased()
        let native = ["com.vng.zalo", "com.vng.zaloformac", "com.facebook.archon", "com.facebook.messenger"].contains(bundle)
        let browsers = ["com.apple.safari","com.google.chrome","com.microsoft.edgemac","org.mozilla.firefox","com.brave.browser","com.coccoc.coccoc"]
        let chat = title.range(of: #"(?:^|[·|—–( -])(Messenger|Zalo)(?:$|[·|—–) -])"#, options: [.regularExpression, .caseInsensitive]) != nil
        guard native || (browsers.contains(bundle) && chat) else { return nil }
        return Self(window: window, bundle: bundle, title: title, native: native)
    }
}

private struct MeetingGrant: Codable, Equatable {
    let bundle: String
    let id: CGWindowID
    let pid: pid_t
    let titleHash: Data
    let native: Bool

    init(_ source: MeetingWindow) {
        bundle = source.bundle
        id = source.id
        pid = source.window.owningApplication?.processID ?? 0
        native = source.native
        titleHash = Self.digest(source.title)
    }
    static func digest(_ title: String) -> Data {
        let stable = title.replacingOccurrences(of: #"^\(\d+\)\s*"#, with: "", options: .regularExpression)
        return Data(SHA256.hash(data: Data(stable.utf8)))
    }
    func matches(_ source: MeetingWindow) -> Bool {
        guard bundle == source.bundle else { return false }
        if native && source.native {
            if source.window.owningApplication?.processID == pid { return id == source.id }
            return titleHash == Self.digest(source.title)
        }
        return id == source.id && pid == source.window.owningApplication?.processID && titleHash == Self.digest(source.title)
    }
}

@MainActor @Observable
final class FRIMeetingAgent {
    private let latencyLog = Logger(subsystem: "com.fri.calendar.native.mac", category: "MeetingLatency")
    private let prefs: UserDefaults
    private var detector: MeetingRecognition?
    private var worker: Task<Void, Never>?
    private var popup: NSPanel?
    private(set) var windows: [MeetingWindow] = []
    private(set) var status = "Đang tắt"
    private(set) var enabled = false
    private(set) var permission = CGPreflightScreenCaptureAccess()
    var loginEnabled: Bool { SMAppService.mainApp.status == .enabled }
    private var grants: [MeetingGrant]

    init(preferences: UserDefaults? = nil) {
        if let preferences {
            prefs = preferences
        } else if ProcessInfo.processInfo.environment["FRI_SYNTHETIC_PREVIEW"] == "1" {
            prefs = UserDefaults(suiteName: "FRI-synthetic-meeting-" + UUID().uuidString)!
        } else {
            prefs = .standard
        }
        grants = prefs.data(forKey: "meeting.sources").flatMap {
            try? JSONDecoder().decode([MeetingGrant].self, from: $0)
        } ?? []
    }
    private var lastImage: Data?
    private var lastSource: Data?
    private var cachedSource: MeetingWindow?
    private var draftSource: Data?
    private var lastComposerImage: Data?
    private var lastDraft: [String: String]?
    private var showingDraft = false

    private func resetFrame() {
        lastImage = nil
        lastComposerImage = nil
        if showingDraft { lastDraft = nil; dismiss() }
        cachedSource = nil
        lastSource = nil
        detector?.reset()
    }
    func isSelected(_ source: MeetingWindow) -> Bool {
        grants.contains { $0.matches(source) }
    }
    private var pending: [String: String]?
    private var waiting: [[String: String]] = []
    weak var calendar: FRICalendarSession?

    func attach(_ calendar: FRICalendarSession) {
        self.calendar = calendar
        if !enabled && !grants.isEmpty && prefs.bool(forKey: "meeting.enabled") { start() }
    }

    func refreshSources(requestPermission: Bool = false) async {
        permission = CGPreflightScreenCaptureAccess()
        if !permission && requestPermission { permission = CGRequestScreenCaptureAccess() }
        guard permission else {
            windows = []; status = "Cần quyền Ghi màn hình để đọc cửa sổ chat đã chọn."
            return
        }
        do {
            let available = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            windows = available.windows.compactMap(MeetingWindow.candidate)
            if !enabled { status = windows.isEmpty ? "Mở Zalo hoặc một cửa sổ riêng cho Messenger, rồi làm mới." : "Chọn một cửa sổ để bật." }
        } catch { windows = []; status = "Không thể liệt kê cửa sổ. Kiểm tra quyền trong macOS." }
    }

    func select(_ source: MeetingWindow) {
        guard permission else { return }
        if !isSelected(source) { grants.append(MeetingGrant(source)) }
        prefs.set(try? JSONEncoder().encode(grants), forKey: "meeting.sources")
        prefs.set(true, forKey: "meeting.enabled")
        start()
    }

    func stop() {
        prefs.set(false, forKey: "meeting.enabled")
        worker?.cancel(); worker = nil
        grants.removeAll()
        prefs.removeObject(forKey: "meeting.sources")
        waiting.removeAll()
        resetFrame()
        lastDraft = nil; draftSource = nil
        enabled = false; detector = nil; dismiss(); status = "Đang tắt"
    }

    func setLogin(_ value: Bool) async {
        do {
            if value { try SMAppService.mainApp.register() }
            else { try await SMAppService.mainApp.unregister() }
            status = loginEnabled ? "Đã bật mở cùng macOS." : "Kiểm tra Mục đăng nhập trong Cài đặt hệ thống."
        } catch { status = "Chưa đổi được mục đăng nhập: " + error.localizedDescription }
    }

    // Drafts are ephemeral. Editing replaces the current proposal, clearing the
    // composer retracts it, and dismissing it suppresses unchanged typing.
    func updateDraft(_ fields: [String: String]?) {
        guard fields != lastDraft else { return }
        lastDraft = fields
        guard let fields else {
            if showingDraft { dismiss() }
            return
        }
        if let pending, !showingDraft { waiting.insert(pending, at: 0) }
        present(fields, draft: true)
    }

    private func start() {
        guard worker == nil else { return }
        do { detector = try MeetingRecognition() } catch { stop(); status = error.localizedDescription; return }
        enabled = true; status = "Đang chờ cửa sổ đã chọn."
        worker = Task { [weak self] in
            while !Task.isCancelled {
                await self?.sample()
                try? await Task.sleep(for: .milliseconds(self?.lastSource == nil ? 600 : 280))
            }
        }
    }

    private func sample() async {
        permission = CGPreflightScreenCaptureAccess()
        guard permission else {
            resetFrame()
            status = "Nhận diện đang tạm dừng. Kiểm tra quyền Ghi màn hình của FRI."
            return
        }
        guard let active = NSWorkspace.shared.frontmostApplication,
              let bundle = active.bundleIdentifier?.lowercased(), grants.contains(where: { $0.bundle == bundle }) else {
            resetFrame(); status = "Chờ bạn quay lại cửa sổ chat."; return
        }
        let pid = active.processIdentifier
        func frontWindow() -> (id: CGWindowID, title: String?)? {
            let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
            guard let window = info?.first(where: { ($0[kCGWindowOwnerPID as String] as? Int32) == pid && ($0[kCGWindowLayer as String] as? Int) == 0 }),
                  let id = window[kCGWindowNumber as String] as? CGWindowID else { return nil }
            return (id, window[kCGWindowName as String] as? String)
        }
        guard let front = frontWindow() else { resetFrame(); return }
        let id = front.id
        do {
            let source: MeetingWindow?
            if let cachedSource, cachedSource.id == id, cachedSource.bundle == bundle,
               cachedSource.window.owningApplication?.processID == pid, front.title == cachedSource.title {
                source = cachedSource
            } else {
                let available = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
                try Task.checkCancellation()
                source = available.windows.first { $0.windowID == id }.flatMap(MeetingWindow.candidate)
            }
            guard let source, source.bundle == bundle, source.window.owningApplication?.processID == pid, isSelected(source) else {
                resetFrame(); status = "Cửa sổ hoặc cuộc chat đã đổi. Chọn lại nguồn."; return
            }
            let sourceKey = MeetingGrant.digest(String(id) + "|" + source.title)
            if lastSource != sourceKey {
                resetFrame()
                lastSource = sourceKey
            }
            if draftSource != sourceKey { lastDraft = nil; draftSource = sourceKey }
            cachedSource = source
            let window = source.window
            let config = SCStreamConfiguration()
            config.ignoreShadowsSingleWindow = true
            config.capturesAudio = false
            config.showsCursor = false
            config.width = min(Int(window.frame.width * 1.5), 2560)
            config.height = Int(window.frame.height * CGFloat(config.width) / window.frame.width)
            let captureStart = ContinuousClock.now
            let image = try await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: config)
            try Task.checkCancellation()
            let signature = MeetingOCR.signature(image)
            let composerSignature = source.isZalo ? MeetingOCR.signature(image, region: .zaloComposer) : nil
            let changedChat = signature == nil || signature != lastImage
            let changedComposer = source.isZalo && (composerSignature == nil || composerSignature != lastComposerImage)
            guard changedChat || changedComposer else { return }
            func stillSelected() async throws -> Bool {
                try Task.checkCancellation()
                guard enabled, isSelected(source), CGPreflightScreenCaptureAccess(),
                      NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
                      let front = frontWindow(), front.id == id else { return false }
                if let title = front.title { return MeetingGrant.digest(title) == MeetingGrant.digest(source.title) }
                let check = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
                try Task.checkCancellation()
                return check.windows.first(where: { $0.windowID == id })?.title == source.title &&
                    NSWorkspace.shared.frontmostApplication?.processIdentifier == pid && frontWindow()?.id == id
            }
            if changedComposer {
                let text = try await Task.detached(priority: .userInitiated) { try MeetingOCR.draftText(image) }.value
                guard try await stillSelected() else { resetFrame(); return }
                lastComposerImage = composerSignature
                let fields = detector?.draft(text)
                let willPresent = fields != nil && fields != lastDraft
                updateDraft(fields)
                if willPresent && showingDraft {
                    let elapsed = captureStart.duration(to: .now)
                    let ms = elapsed.components.seconds * 1000 + elapsed.components.attoseconds / 1_000_000_000_000_000
                    latencyLog.info("Draft suggestion shown, capture to panel: \(ms, privacy: .public) ms")
                }
            }
            guard changedChat else { return }
            let rows = try await Task.detached(priority: .userInitiated) { try MeetingOCR.rows(image) }.value
            guard try await stillSelected() else { resetFrame(); return }
            lastImage = signature
            status = "Đang nhận diện trên máy · " + (source.native ? "cửa sổ chat" : "cửa sổ trình duyệt đã chọn")
            if let suggestion = detector?.observe(rows) {
                if pending == nil { present(suggestion) }
                else if waiting.count < 32 { waiting.append(suggestion) }
            }
        } catch {
            if !Task.isCancelled { resetFrame(); status = "Nguồn tạm dừng. Kiểm tra cửa sổ và quyền." }
        }
    }

    func tryExample() {
        guard pending == nil, let example = try? MeetingRecognition() else { return }
        let question = ["side": "other", "text": "Mai 19h họp nhé?"]
        _ = example.observe([question])
        if let result = example.observe([question, ["side": "own", "text": "Ok, mình đi"]]) {
            present(result, example: true)
        }
    }

    func dismiss() {
        popup?.orderOut(nil)
        popup = nil
        pending = nil
        showingDraft = false
        if !waiting.isEmpty { present(waiting.removeFirst()) }
    }

    private func present(_ fields: [String: String], example: Bool = false, draft: Bool = false) {
        guard let screen = NSScreen.main else { return }
        pending = fields
        showingDraft = draft
        let panel = popup ?? NSPanel(contentRect: NSRect(x: 0,y: 0,width: 340,height: 140), styleMask: [.nonactivatingPanel,.titled,.fullSizeContentView], backing: .buffered, defer: false)
        panel.title = draft ? "FRI · Gợi ý khi đang soạn" : "FRI · Nhắc kèo"; panel.isFloatingPanel = true; panel.hidesOnDeactivate = false; panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: VStack(alignment: .leading, spacing: 8) {
            Text(draft ? "Bạn có muốn lên lịch hẹn này?" : (example ? "Thử với ví dụ · Thêm vào lịch FRI?" : "Thêm vào lịch FRI?")).font(.headline)
            Text([fields["title"] ?? "Cuộc hẹn", fields["location"]].compactMap { $0 }.joined(separator: " · "))
            Text([fields["date"] ?? "Chưa rõ ngày", fields["time"] ?? fields["timeHint"].map { $0 + " (sáng hay tối?)" } ?? "Chưa rõ giờ"].joined(separator: " · ")).font(.subheadline)
            HStack {
                Button("Bỏ qua") { self.dismiss() }
                Button("Xem và lưu") { self.review() }.buttonStyle(.borderedProminent)
            }
        }.padding().frame(maxWidth: .infinity, alignment: .leading))
        panel.setFrameTopLeftPoint(NSPoint(x:screen.visibleFrame.maxX-355,y:screen.visibleFrame.maxY-12))
        popup=panel; panel.orderFrontRegardless()
    }

    func review() {
        guard let calendar, calendar.ready, let fields=pending else { return }
        var item=Appointment()
        item.title=fields["title"] ?? "Cuộc hẹn"; item.date=fields["date"] ?? ""; item.time=fields["time"] ?? ""
        item.kind="schedule"; item.duration=0; item.location=fields["location"] ?? ""
        if let hint = fields["timeHint"] { item.notes = "Giờ cần xác nhận: " + hint }
        if calendar.addDrafts([item]) { dismiss(); calendar.newDraft(deadline:false,startingID:item.id) }
    }
}

struct FRIMeetingAgentSettings: View {
    @Bindable var agent: FRIMeetingAgent
    var body: some View {
        Form {
            Section("Thư ký lịch") {
                Text(agent.status)
                Text("Chọn cửa sổ Zalo, Messenger hoặc cửa sổ trình duyệt riêng cho từng cuộc chat. Bạn có thể chọn nhiều nguồn. Khi bạn đang xem cửa sổ đã chọn, FRI đọc vùng hội thoại và gợi ý ngay lúc bạn đang soạn lời hẹn trên Zalo. Bạn quyết định có ghi vào lịch hay không.").font(.callout)
                Button(agent.permission ? "Làm mới danh sách cửa sổ" : "Cho phép chọn cửa sổ chat…") {
                    Task { await agent.refreshSources(requestPermission: true) }
                }
                ForEach(agent.windows) { source in
                    Button { agent.select(source) } label: {
                        Label(source.title, systemImage: agent.isSelected(source) ? "checkmark.circle.fill" : "plus.circle")
                    }
                }
                if agent.enabled { Button("Tắt nhận diện") { agent.stop() } }
                Button("Thử với hội thoại mẫu") { agent.tryExample() }
                    .accessibilityIdentifier("fri.meeting.example")
                Toggle("Mở FRI khi đăng nhập", isOn: Binding(get:{ agent.loginEnabled },set:{ value in Task { await agent.setLogin(value) } }))
            }
        }.formStyle(.grouped).frame(minWidth: 420, minHeight: 310).task { await agent.refreshSources() }
    }
}
#endif
