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

    var webSource: MeetingWebSource? {
        guard !native else { return nil }
        return MeetingWebSource(browser: bundle, service: isZalo ? .zalo : .messenger)
    }

    static let nativeBundles: Set<String> = ["com.vng.zalo", "com.vng.zaloformac", "com.facebook.archon", "com.facebook.messenger"]

    static func chatTitle(_ title: String) -> Bool {
        title.range(of: #"(?:^|[·|—–( -])(Messenger|Zalo)(?:$|[·|—–) -])"#, options: [.regularExpression, .caseInsensitive]) != nil
    }
    static func candidate(_ window: SCWindow) -> Self? {
        guard window.windowLayer == 0, let app = window.owningApplication,
              let title = window.title, !title.isEmpty, window.frame.width >= 360, window.frame.height >= 260 else { return nil }
        guard title.range(of: #"đăng nhập|mật khẩu|xác thực|thanh toán|password|sign in|login|payment|verification"#,
                          options: [.regularExpression, .caseInsensitive]) == nil else { return nil }
        let bundle = app.bundleIdentifier.lowercased()
        let native = nativeBundles.contains(bundle)
        let browsers = ["com.apple.safari","com.google.chrome","com.microsoft.edgemac","org.mozilla.firefox","com.brave.browser","com.coccoc.coccoc"]
        guard native || (browsers.contains(bundle) && chatTitle(title)) else { return nil }
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
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    private var suspendedBy = Set<Notification.Name>()
    private var samplingPID: pid_t?
    private var quietFrames = 0
    // One in-flight screenshot/OCR even across a rapid foreground change.
    private var samplingFrame = false
    private var popup: NSPanel?
    private(set) var windows: [MeetingWindow] = []
    private(set) var status = "Đang tắt"
    private(set) var enabled = false
    private(set) var permission = CGPreflightScreenCaptureAccess()
    private(set) var loginStatus = SMAppService.mainApp.status
    var loginEnabled: Bool { loginStatus == .enabled || loginStatus == .requiresApproval }
    private var nativeApps: Set<String>
    private let browserReader = MeetingBrowserReader()
    private(set) var webSources: Set<MeetingWebSource>
    private var consentGeneration = 0
    var hasSources: Bool { !grants.isEmpty || !nativeApps.isEmpty || !webSources.isEmpty }
    var hasSamplingTask: Bool { worker != nil }
    private var grants: [MeetingGrant]

    init(preferences: UserDefaults? = nil) {
        if let preferences {
            prefs = preferences
        } else if ProcessInfo.processInfo.environment["FRI_SYNTHETIC_PREVIEW"] == "1" {
            prefs = UserDefaults(suiteName: "FRI-synthetic-meeting-" + UUID().uuidString)!
        } else {
            prefs = .standard
        }
        webSources = prefs.data(forKey: "meeting.webSources").flatMap { try? JSONDecoder().decode(Set<MeetingWebSource>.self, from: $0) } ?? []
        nativeApps = Set(prefs.stringArray(forKey: "meeting.nativeApps") ?? []).intersection(MeetingWindow.nativeBundles)
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
        quietFrames = 0
        lastImage = nil
        lastComposerImage = nil
        if showingDraft { lastDraft = nil; closePanel() }
        cachedSource = nil
        lastSource = nil
        detector?.reset()
    }
    func isSelected(_ source: MeetingWindow) -> Bool {
        (source.native && nativeApps.contains(source.bundle)) || grants.contains { $0.matches(source) }
    }
    private var pending: [String: String]?
    private var waiting: [[String: String]] = []
    weak var calendar: FRICalendarSession?

    func attach(_ calendar: FRICalendarSession) {
        self.calendar = calendar
        if !enabled && hasSources && prefs.bool(forKey: "meeting.enabled") { resume() }
    }

    func refreshSources(requestPermission: Bool = false) async {
        loginStatus = SMAppService.mainApp.status
        permission = CGPreflightScreenCaptureAccess()
        if !permission && requestPermission { permission = CGRequestScreenCaptureAccess() }
        guard permission else {
            windows = []; status = "Cần quyền Ghi màn hình để đọc cửa sổ chat đã chọn."
            return
        }
        do {
            let available = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            guard !Task.isCancelled else { return }
            windows = available.windows.compactMap(MeetingWindow.candidate)
            if enabled { reconcileForeground() }
            if !enabled { status = windows.isEmpty ? "Mở Zalo hoặc một cửa sổ riêng cho Messenger, rồi làm mới." : "Chọn một cửa sổ để bật." }
        } catch {
            guard !Task.isCancelled else { return }
            windows = []
            status = "Không thể liệt kê cửa sổ. Kiểm tra quyền trong macOS."
        }
    }

    func select(_ source: MeetingWindow) {
        guard permission else { return }
        if source.native {
            nativeApps.insert(source.bundle)
            prefs.set(nativeApps.sorted(), forKey: "meeting.nativeApps")
        } else if !isSelected(source) {
            // Replace stale identities for the same, explicitly reselected browser window.
            let grant = MeetingGrant(source)
            grants.removeAll { $0.bundle == grant.bundle && $0.titleHash == grant.titleHash && $0.pid != grant.pid }
            grants.append(grant)
            prefs.set(try? JSONEncoder().encode(grants), forKey: "meeting.sources")
        }
        resume()
    }

    func rememberWeb(_ source: MeetingWindow) async {
        guard permission, let web = source.webSource, let pid = source.window.owningApplication?.processID else { return }
        let generation = consentGeneration
        let allowed = await browserReader.permitted(pid: pid, ask: true)
        guard generation == consentGeneration, !Task.isCancelled else { return }
        guard allowed else {
            status = "Chưa có quyền Tự động hóa cho trình duyệt. Bạn vẫn có thể chọn riêng cửa sổ."
            return
        }
        webSources.insert(web)
        prefs.set(try? JSONEncoder().encode(webSources), forKey: "meeting.webSources")
        resume()
    }

    func pause() {
        prefs.set(false, forKey: "meeting.enabled")
        shutdown()
        status = "Đã tạm dừng · Đã nhớ nguồn."
    }

    func stop() {
        pause()
        grants.removeAll()
        nativeApps.removeAll()
        webSources.removeAll()
        prefs.removeObject(forKey: "meeting.webSources")
        prefs.removeObject(forKey: "meeting.sources")
        prefs.removeObject(forKey: "meeting.nativeApps")
        status = "Đang tắt"
    }

    func shutdown() {
        consentGeneration += 1
        enabled = false
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach(center.removeObserver)
        observers.removeAll()
        suspendedBy.removeAll()
        waiting.removeAll()
        closePanel()
        cancelSampling()
        windows.removeAll()
    }

    func clearWindowList() { windows.removeAll() }

    func setLogin(_ value: Bool) async {
        do {
            if value { try SMAppService.mainApp.register() }
            else { try await SMAppService.mainApp.unregister() }
            loginStatus = SMAppService.mainApp.status
            if loginStatus == .requiresApproval { status = "Cho phép FRI trong Cài đặt hệ thống → Mục đăng nhập." }
            else { status = loginEnabled ? "Đã bật mở cùng macOS." : "Đã tắt mở cùng macOS." }
        } catch { status = "Chưa đổi được mục đăng nhập: " + error.localizedDescription }
    }

    // Drafts are ephemeral. Editing replaces the current proposal, clearing the
    // composer retracts it, and dismissing it suppresses unchanged typing.
    func updateDraft(_ fields: [String: String]?) {
        guard fields != lastDraft else { return }
        lastDraft = fields
        guard let fields else {
            if showingDraft { closePanel() }
            return
        }
        if let pending, !showingDraft { waiting.insert(pending, at: 0) }
        present(fields, draft: true)
    }

    func resume() {
        guard hasSources else { return }
        prefs.set(true, forKey: "meeting.enabled")
        if !enabled {
            permission = CGPreflightScreenCaptureAccess()
            enabled = true
            let center = NSWorkspace.shared.notificationCenter
            for name in [NSWorkspace.didActivateApplicationNotification,
                         NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification,
                         NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification,
                         NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
                observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                    let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
                    MainActor.assumeIsolated {
                        self?.workspaceChanged(name, activated: pid.flatMap(NSRunningApplication.init(processIdentifier:)))
                    }
                })
            }
        }
        reconcileForeground()
    }

    private func workspaceChanged(_ name: Notification.Name, activated: NSRunningApplication?) {
        guard enabled else { return }
        switch name {
        case NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification:
            suspendedBy.insert(name)
        case NSWorkspace.didWakeNotification: suspendedBy.remove(NSWorkspace.willSleepNotification)
        case NSWorkspace.screensDidWakeNotification: suspendedBy.remove(NSWorkspace.screensDidSleepNotification)
        case NSWorkspace.sessionDidBecomeActiveNotification: suspendedBy.remove(NSWorkspace.sessionDidResignActiveNotification)
        default: break
        }
        reconcileForeground(activated)
    }

    private func cancelSampling() {
        worker?.cancel()
        worker = nil
        samplingPID = nil
        quietFrames = 0
        resetFrame()
        detector = nil
        draftSource = nil
        lastDraft = nil
    }

    private func reconcileForeground(_ activated: NSRunningApplication? = nil) {
        guard enabled else { return }
        let active = activated ?? NSWorkspace.shared.frontmostApplication
        guard suspendedBy.isEmpty, let active, let bundle = active.bundleIdentifier?.lowercased(),
              nativeApps.contains(bundle) || webSources.contains(where: { $0.browser == bundle }) || grants.contains(where: { $0.bundle == bundle }) else {
            if worker != nil { cancelSampling() }
            status = permission ? "Chạy nền · Chờ ứng dụng chat đã chọn." : "Đã nhớ nguồn. Mở Thư ký lịch để cấp quyền Ghi màn hình."
            return
        }
        guard samplingPID != active.processIdentifier || worker == nil else { return }
        cancelSampling()
        permission = CGPreflightScreenCaptureAccess()
        guard permission else {
            status = "Đang chờ quyền Ghi màn hình. Mở Thư ký lịch để kiểm tra."
            return
        }
        samplingPID = active.processIdentifier
        worker = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if !self.samplingFrame {
                    self.samplingFrame = true
                    await self.sample(bundle: bundle, pid: active.processIdentifier)
                    self.samplingFrame = false
                }
                guard !Task.isCancelled else { return }
                do { try await Task.sleep(for: self.sampleDelay, tolerance: .milliseconds(40)) }
                catch { return }
            }
        }
    }

    var sampleDelay: Duration {
        guard lastSource != nil else { return .milliseconds(1100) }
        return quietFrames >= 6 ? .milliseconds(750) : .milliseconds(280)
    }

    private func sample(bundle: String, pid: pid_t) async {
        permission = CGPreflightScreenCaptureAccess()
        guard permission else {
            cancelSampling()
            status = "Đang chờ quyền Ghi màn hình. Mở Thư ký lịch để kiểm tra."
            return
        }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else {
            resetFrame()
            return
        }
        func frontWindow() -> (id: CGWindowID, title: String?)? {
            let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
            guard let window = info?.first(where: { ($0[kCGWindowOwnerPID as String] as? Int32) == pid && ($0[kCGWindowLayer as String] as? Int) == 0 }),
                  let id = window[kCGWindowNumber as String] as? CGWindowID else { return nil }
            return (id, window[kCGWindowName as String] as? String)
        }
        guard let front = frontWindow() else { resetFrame(); return }
        let id = front.id
        let hasWebGrant = (front.title.map(MeetingWindow.chatTitle) ?? true) && webSources.contains { $0.browser == bundle }
        if !nativeApps.contains(bundle) && !hasWebGrant && !grants.contains(where: {
            guard $0.bundle == bundle else { return false }
            if $0.native && $0.pid != pid { return true }
            guard $0.pid == pid, $0.id == id else { return false }
            if !$0.native, let title = front.title { return $0.titleHash == MeetingGrant.digest(title) }
            return true
        }) {
            if lastSource != nil { resetFrame() }
            status = "Chờ cửa sổ chat đã chọn."
            return
        }
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
            guard let source, source.bundle == bundle, source.window.owningApplication?.processID == pid else {
                resetFrame(); status = "Chờ cửa sổ chat đã chọn."; return
            }
            let web = source.webSource.flatMap { webSources.contains($0) ? $0 : nil }
            var route: Data?
            if let web {
                route = await browserReader.activeRoute(web, pid: pid)
                try Task.checkCancellation()
                guard route != nil else {
                    resetFrame(); status = "Chờ trang chat đã xác minh. Kiểm tra quyền Tự động hóa nếu cần."; return
                }
            } else if !isSelected(source) {
                resetFrame(); status = "Cửa sổ hoặc cuộc chat đã đổi. Chọn lại nguồn."; return
            }
            let sourceKey = MeetingGrant.digest(String(id) + "|" + source.title) + (route ?? Data())
            if lastSource != sourceKey {
                resetFrame()
                lastSource = sourceKey
            }
            if draftSource != sourceKey { lastDraft = nil; draftSource = sourceKey }
            cachedSource = source
            if detector == nil { detector = try MeetingRecognition() }
            let window = source.window
            let config = SCStreamConfiguration()
            config.ignoreShadowsSingleWindow = true
            config.capturesAudio = false
            config.showsCursor = false
            config.width = min(Int(window.frame.width * 1.5), 2560)
            config.height = Int(window.frame.height * CGFloat(config.width) / window.frame.width)
            let captureStart = ContinuousClock.now
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
                  let current = frontWindow(), current.id == id,
                  current.title == nil || current.title == source.title else { resetFrame(); return }
            let image = try await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: config)
            try Task.checkCancellation()
            let signature = MeetingOCR.signature(image)
            let composerSignature = source.isZalo ? MeetingOCR.signature(image, region: .zaloComposer) : nil
            let changedChat = signature == nil || signature != lastImage
            let changedComposer = source.isZalo && (composerSignature == nil || composerSignature != lastComposerImage)
            guard changedChat || changedComposer else {
                quietFrames = min(quietFrames + 1, 6)
                return
            }
            quietFrames = 0
            func stillSelected() async throws -> Bool {
                try Task.checkCancellation()
                guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid, frontWindow()?.id == id else { return false }
                if let web {
                    guard webSources.contains(web), let current = await browserReader.activeRoute(web, pid: pid),
                          current == route else { return false }
                    try Task.checkCancellation()
                } else if !isSelected(source) { return false }
                guard enabled, CGPreflightScreenCaptureAccess(),
                      NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
                      let front = frontWindow(), front.id == id else { return false }
                if let title = front.title { return MeetingGrant.digest(title) == MeetingGrant.digest(source.title) }
                let check = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
                try Task.checkCancellation()
                return check.windows.first(where: { $0.windowID == id })?.title == source.title &&
                    NSWorkspace.shared.frontmostApplication?.processIdentifier == pid && frontWindow()?.id == id
            }
            var clearComposer = false
            if changedComposer {
                let text = try await Task.detached(priority: .userInitiated) { try MeetingOCR.draftText(image) }.value
                guard try await stillSelected() else { resetFrame(); return }
                lastComposerImage = composerSignature
                let fields = detector?.draft(text)
                let willPresent = fields != nil && fields != lastDraft
                if let fields { updateDraft(fields) } else { clearComposer = true }
                if willPresent && showingDraft {
                    let elapsed = captureStart.duration(to: .now)
                    let ms = elapsed.components.seconds * 1000 + elapsed.components.attoseconds / 1_000_000_000_000_000
                    latencyLog.info("Draft suggestion shown, capture to panel: \(ms, privacy: .public) ms")
                }
            }
            guard changedChat else {
                if clearComposer { updateDraft(nil) }
                return
            }
            let rows = try await Task.detached(priority: .userInitiated) { try MeetingOCR.rows(image) }.value
            guard try await stillSelected() else { resetFrame(); return }
            lastImage = signature
            status = "Đang nhận diện trên máy · " + (source.native ? "cửa sổ chat" : "cửa sổ trình duyệt đã chọn")
            applyConversation(detector?.observe(rows, includeSentInvites: source.isZalo), composerCleared: clearComposer)
        } catch {
            if !Task.isCancelled { resetFrame(); status = "Nguồn tạm dừng. Kiểm tra cửa sổ và quyền." }
        }
    }

    func applyConversation(_ suggestion: [String: String]?, composerCleared: Bool) {
        if let suggestion {
            let justSentDraft = showingDraft && composerCleared && suggestion["origin"] == "sentInvitation"
            if pending == nil || justSentDraft {
                present(suggestion)
            } else if waiting.count < 32 {
                waiting.append(suggestion)
            }
        }
        if composerCleared { updateDraft(nil) }
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
        if showingDraft { detector?.handleDraft() }
        closePanel()
    }

    private func closePanel() {
        popup?.orderOut(nil)
        popup = nil
        pending = nil
        showingDraft = false
        if !waiting.isEmpty { present(waiting.removeFirst()) }
    }

    private func present(_ fields: [String: String], example: Bool = false, draft: Bool = false) {
        guard let screen = NSScreen.main else { return }
        let invitation = draft || fields["origin"] == "sentInvitation"
        pending = fields
        showingDraft = draft
        let panel = popup ?? NSPanel(contentRect: NSRect(x: 0,y: 0,width: 340,height: 140), styleMask: [.nonactivatingPanel,.titled,.fullSizeContentView], backing: .buffered, defer: false)
        panel.title = draft ? "FRI · Gợi ý khi đang soạn" : "FRI · Nhắc kèo"; panel.isFloatingPanel = true; panel.hidesOnDeactivate = false; panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: VStack(alignment: .leading, spacing: 8) {
            Text(invitation ? "Bạn có muốn lên lịch hẹn này?" : (example ? "Thử với ví dụ · Thêm vào lịch FRI?" : "Thêm vào lịch FRI?")).font(.headline)
            Text([fields["title"] ?? "Cuộc hẹn", fields["location"]].compactMap { $0 }.joined(separator: " · "))
            Text([fields["date"] ?? "Chưa rõ ngày", fields["time"] ?? fields["timeHint"].map { $0 + " (sáng hay tối?)" } ?? fields["relativeTime"].map { $0 + " · Mấy giờ?" } ?? "Chưa rõ giờ"].joined(separator: " · ")).font(.subheadline)
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
        if let hint = fields["timeHint"] ?? fields["relativeTime"] { item.notes = "Giờ cần xác nhận: " + hint }
        if calendar.addDrafts([item]) { dismiss(); calendar.newDraft(deadline:false,startingID:item.id) }
    }
}

private extension Array where Element == MeetingWindow {
    var uniquedWebSources: [MeetingWindow] {
        var seen = Set<MeetingWebSource>()
        return filter { source in source.webSource.map { seen.insert($0).inserted } ?? false }
    }
}

struct FRIMeetingAgentSettings: View {
    @Bindable var agent: FRIMeetingAgent
    @State private var refreshTask: Task<Void, Never>?
    var body: some View {
        Form {
            Section("Thư ký lịch") {
                Text(agent.status)
                Text("Chọn ứng dụng Zalo/Messenger để ghi nhớ cả sau khi mở lại. Với Chrome/Safari, chọn Nhớ trang để tự nhận lại đúng trang chat sau khi mở lại trình duyệt. macOS có thể hỏi quyền Tự động hóa để kiểm tra địa chỉ tab. Bạn cũng có thể chọn riêng một cửa sổ. FRI chờ trên thanh menu khi bạn đóng lịch và chỉ đọc vùng chat khi nguồn ở phía trước.").font(.callout)
                Button(agent.permission ? "Làm mới danh sách cửa sổ" : "Cho phép chọn cửa sổ chat…") {
                    refreshTask?.cancel()
                    refreshTask = Task { await agent.refreshSources(requestPermission: true) }
                }
                ForEach(agent.windows) { source in
                    Button { agent.select(source) } label: {
                        Label(source.native ? "Ghi nhớ ứng dụng " + (source.isZalo ? "Zalo" : "Messenger") : source.title, systemImage: agent.isSelected(source) ? "checkmark.circle.fill" : "plus.circle")
                    }
                }
                ForEach(agent.windows.uniquedWebSources) { source in
                    if let web = source.webSource {
                        Button(agent.webSources.contains(web) ? "Đã nhớ " + web.label : "Nhớ trang " + web.label) {
                            Task { await agent.rememberWeb(source) }
                        }.disabled(agent.webSources.contains(web))
                    }
                }
                if agent.hasSources {
                    Button(agent.enabled ? "Tạm dừng nhận diện" : "Tiếp tục nhận diện") {
                        if agent.enabled { agent.pause() } else { agent.resume() }
                    }
                    Button("Quên các nguồn đã chọn", role: .destructive) { agent.stop() }
                }
                Button("Thử với hội thoại mẫu") { agent.tryExample() }
                    .accessibilityIdentifier("fri.meeting.example")
                Toggle("Mở FRI khi đăng nhập", isOn: Binding(get:{ agent.loginEnabled },set:{ value in Task { await agent.setLogin(value) } }))
            }
        }.formStyle(.grouped).frame(minWidth: 420, minHeight: 310).task { await agent.refreshSources() }
        .onDisappear {
            refreshTask?.cancel()
            refreshTask = nil
            agent.clearWindowList()
        }
    }
}
#endif
