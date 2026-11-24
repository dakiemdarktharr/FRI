#if os(macOS)
import AppKit
import FRICore
import FRIDesign
import SwiftUI
import WidgetKit

/// AppKit owns panel identity, placement and lifetime; SwiftUI owns adaptive content.
@MainActor
final class FRIDesktopWidgetManager: NSObject, NSWindowDelegate {
    private struct Configuration: Codable {
        let id: UUID
        var day: String?
        var pinned = false
    }

    private weak var calendar: FRICalendarSession?
    private var configurations: [Configuration] = []
    private var panels: [UUID: NSPanel] = [:]
    private let defaultsKey: String
    private var terminating = false

    init(calendar: FRICalendarSession) {
        self.calendar = calendar
        let scope = calendar.synthetic ? (ProcessInfo.processInfo.environment["FRI_TEST_STORE_ID"] ?? "preview") : "calendar"
        defaultsKey = "FRI.DesktopWidgets.\(scope)"
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillTerminate),
                                               name: NSApplication.willTerminateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screenConfigurationChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode([Configuration].self, from: data) {
            configurations = Array(saved.prefix(12))
        }
        for configuration in configurations { open(configuration) }
    }

    func add() {
        guard configurations.count < 12 else {
            calendar?.message = "You can keep up to 12 desktop widgets. Close one to add another."
            return
        }
        let configuration = Configuration(id: UUID())
        configurations.append(configuration)
        persist()
        open(configuration)
        panels[configuration.id]?.makeKeyAndOrderFront(nil)
    }

    func showAll() {
        if panels.isEmpty { add() }
        else {
            for panel in panels.values {
                constrainToScreen(panel)
                panel.orderFrontRegardless()
            }
            panels.values.first?.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func applicationWillTerminate(_ notification: Notification) { terminating = true }

    @objc private func screenConfigurationChanged(_ notification: Notification) {
        for panel in panels.values { constrainToScreen(panel) }
    }

    private func open(_ configuration: Configuration) {
        guard let calendar, panels[configuration.id] == nil else { return }
        let panel = FRIDesktopPanel(contentRect: NSRect(x: 100, y: 100, width: 360, height: 210),
                                    styleMask: [.borderless, .resizable, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "FRI Desktop Widget"
        panel.identifier = NSUserInterfaceItemIdentifier(configuration.id.uuidString)
        panel.isReleasedWhenClosed = false
        panel.isExcludedFromWindowsMenu = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = false
        panel.level = configuration.pinned ? .floating : .normal
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovable = true
        panel.isMovableByWindowBackground = false
        panel.contentMinSize = NSSize(width: 220, height: 140)
        panel.contentMaxSize = NSSize(width: 900, height: 1000)
        panel.delegate = self
        panels[configuration.id] = panel
        installContent(configuration, calendar: calendar, panel: panel)
        let frameName = defaultsKey + "." + configuration.id.uuidString
        panel.setFrameAutosaveName(frameName)
        if !panel.setFrameUsingName(frameName) { panel.center() }
        constrainToScreen(panel)
        panel.orderFrontRegardless()
    }

    private func installContent(_ configuration: Configuration, calendar: FRICalendarSession, panel: NSPanel) {
        panel.contentView = NSHostingView(rootView: FRIDesktopWidgetView(
            calendar: calendar, day: configuration.day, pinned: configuration.pinned,
            close: { [weak panel] in panel?.close() },
            resize: { [weak self] size in self?.resize(configuration.id, to: size) },
            move: { [weak self, weak panel] dx, dy in
                guard let self, let panel else { return }
                panel.setFrameOrigin(NSPoint(x: panel.frame.minX + dx, y: panel.frame.minY + dy))
                self.constrainToScreen(panel)
            },
            pin: { [weak self] in self?.configure(configuration.id) { $0.pinned.toggle() } },
            followToday: { [weak self] in self?.configure(configuration.id) { $0.day = nil } },
            useSelection: { [weak self, weak calendar] in self?.configure(configuration.id) { $0.day = calendar?.state.active } },
            showCalendar: { [weak calendar] in
                guard let calendar else { return }
                calendar.select(configuration.day ?? CalendarClock.day())
                calendar.revealCalendar?()
                NSApp.activate(ignoringOtherApps: true)
            }
        ))
    }

    private func configure(_ id: UUID, _ update: (inout Configuration) -> Void) {
        guard let index = configurations.firstIndex(where: { $0.id == id }), let panel = panels[id], let calendar else { return }
        update(&configurations[index])
        panel.level = configurations[index].pinned ? .floating : .normal
        installContent(configurations[index], calendar: calendar, panel: panel)
        persist()
    }

    private func resize(_ id: UUID, to size: NSSize) {
        guard let panel = panels[id] else { return }
        var frame = panel.frame
        frame.origin.y += frame.height - size.height
        frame.size = size
        panel.setFrame(frame, display: true, animate: false)
        constrainToScreen(panel)
    }

    private func constrainToScreen(_ panel: NSPanel) {
        // Read current visible frames each time; Dock/menu bar and display settings can change.
        let frame = DesktopWidgetPlacement.fitting(panel.frame, visibleFrames: NSScreen.screens.map(\.visibleFrame))
        if frame != panel.frame { panel.setFrame(frame, display: true) }
    }

    func windowWillClose(_ notification: Notification) {
        guard !terminating, let panel = notification.object as? NSPanel,
              let raw = panel.identifier?.rawValue, let id = UUID(uuidString: raw) else { return }
        configurations.removeAll { $0.id == id }
        panels[id] = nil
        panel.contentView = nil
        NSWindow.removeFrame(usingName: defaultsKey + "." + raw)
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(configurations) { UserDefaults.standard.set(data, forKey: defaultsKey) }
    }
}

private final class FRIDesktopPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct FRIDesktopWidgetView: View {
    @Bindable var calendar: FRICalendarSession
    let day: String?
    let pinned: Bool
    let close: () -> Void
    let resize: (NSSize) -> Void
    let move: (CGFloat, CGFloat) -> Void
    let pin: () -> Void
    let followToday: () -> Void
    let useSelection: () -> Void
    let showCalendar: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                FRIPanelDragRegion()
                    .overlay(alignment: .leading) {
                        Label(calendar.synthetic ? "FRI · Preview" : "FRI", systemImage: "circle.grid.2x2.fill")
                            .friFont(.caption, weight: .semibold).padding(.leading, 12).allowsHitTesting(false)
                    }
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .help("Drag here to move the widget")
                Menu {
                    Button("Small") { resize(NSSize(width: 240, height: 180)) }
                    Button("Medium") { resize(NSSize(width: 360, height: 210)) }
                    Button("Large") { resize(NSSize(width: 360, height: 390)) }
                    Menu("Move widget") {
                        Button("Move left") { move(-40, 0) }
                        Button("Move right") { move(40, 0) }
                        Button("Move up") { move(0, 40) }
                        Button("Move down") { move(0, -40) }
                    }
                    Divider()
                    Button(pinned ? "Stop keeping on top" : "Keep on top", action: pin)
                    Button("Follow today", action: followToday)
                    Button("Use selected calendar day", action: useSelection)
                    Button("Open calendar", action: showCalendar)
                } label: { Image(systemName: "ellipsis") }
                .menuStyle(.borderlessButton).tint(FRIColors.muted).frame(width: 26).accessibilityLabel("Widget options")
                Button("Close widget", systemImage: "xmark", action: close)
                    .labelStyle(.iconOnly).buttonStyle(.plain).frame(width: 32, height: 32)
            }
            .frame(height: 32)
            .foregroundStyle(FRIColors.muted)
            TimelineView(.periodic(from: .now, by: 30)) { context in
                GeometryReader { geometry in
                    let selected = day.flatMap { CalendarClock.date($0) } ?? context.date
                    let snapshot = calendar.ready ? WidgetSnapshot(state: calendar.state, day: selected, now: context.date) : WidgetSnapshot(day: selected, locked: true)
                    FRIWidgetContent(snapshot: snapshot,
                                     family: geometry.size.height >= 290 ? .systemLarge : (geometry.size.width >= 280 ? .systemMedium : .systemSmall), tint: FRIColors.accent, secondaryColor: FRIColors.muted) {
                        if let next = snapshot.tasks.first, let item = calendar.state.tasks.first(where: { $0.id == next.id }) {
                            Button { calendar.setDoneWithoutOpening(item) } label: {
                                Image(systemName: "checkmark.circle.fill").friFont(.title2)
                            }.buttonStyle(.plain).accessibilityLabel("Complete \(next.title)")
                        }
                    }
                    .foregroundStyle(FRIColors.ink).tint(FRIColors.accent)
                    .padding(14).frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(FRIColors.control, in: RoundedRectangle(cornerRadius: 18))
                    .accessibilityIdentifier("fri.desktopWidget.content")
                }
            }
            .padding(.horizontal, 12).padding(.bottom, 12)
        }
        .background(FRIColors.surface, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(FRIColors.line))
        .overlay(alignment: .bottomTrailing) {
            FRIPanelResizeRegion().frame(width: 24, height: 24)
                .overlay { Image(systemName: "arrow.down.right").friFont(.caption2).foregroundStyle(FRIColors.muted).allowsHitTesting(false) }
                .help("Drag to resize; content fits automatically")
        }
        .environment(\.dynamicTypeSize, calendar.state.settings["large"]?.bool == true ? .xxxLarge : .large)
        .environment(\.colorScheme, .light)
        .accessibilityIdentifier("fri.desktopWidget")
    }
}

private struct FRIPanelDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

private struct FRIPanelResizeRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ResizeView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class ResizeView: NSView {
        private var start = NSRect.zero
        private var mouse = NSPoint.zero
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) {
            start = window?.frame ?? .zero
            mouse = NSEvent.mouseLocation
        }
        override func mouseDragged(with event: NSEvent) {
            guard let window else { return }
            let cursor = NSEvent.mouseLocation
            let width = min(window.maxSize.width, max(window.minSize.width, start.width + cursor.x - mouse.x))
            let height = min(window.maxSize.height, max(window.minSize.height, start.height - cursor.y + mouse.y))
            window.setFrame(NSRect(x: start.minX, y: start.maxY - height, width: width, height: height), display: true)
        }
    }
}
#endif
