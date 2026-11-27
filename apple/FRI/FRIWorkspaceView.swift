import FRICore
import FRIDesign
import SwiftUI
import UniformTypeIdentifiers

struct FRIWorkspaceView: View {
    @Bindable var calendar: FRICalendarSession
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.openWindow) private var openWindow
    #if os(macOS)
    @State private var showUsageGuide = false
    @State private var keyboardNewMenu = false
    @FocusState private var focusedTab: String?
    @FocusState private var region: Int?

    #endif
    @FocusState private var feedFocus: FeedFocus?
    @State private var feedDays = 14
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var replayFirstPlan = false
    @State private var showSidebar = true
    @State private var showUpcoming = false
    @State private var fileExport: FRIFile?
    @State private var exporting = false
    @State private var importing = false
    @State private var fileName = "FRI-backup"
    @State private var pendingRead: FRICalendarSession.FileAction?
    @State private var searchedAppointment: Appointment?

    private var selected: Date { CalendarClock.date(calendar.state.active) ?? .now }
    private var dayTasks: [Appointment] { calendar.state.tasks(on: calendar.state.active) }
    private var complete: Int { dayTasks.filter(\.done).count }
    private var finished: Bool { calendar.state.finished.contains(.string(calendar.state.active)) }
    private var effectiveType: DynamicTypeSize {
        calendar.state.settings["large"]?.bool == true ? max(typeSize, .xxxLarge) : typeSize
    }
    private var glass: Bool { calendar.state.settings["glass"]?.bool != false }

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 800
            HStack(spacing: 0) {
                if wide && showSidebar {
                    sidebar.frame(width: 235)
                        #if os(macOS)
                        .focusable().focused($region, equals: 0)
                        #endif
                }
                VStack(alignment: .leading, spacing: 0) {
                    toolbar(wide: wide)
                        #if os(macOS)
                        .focusable().focused($region, equals: 1)
                        #endif
                    if calendar.synthetic {
                        Text("Development preview · sample data only")
                            .friFont(.caption).foregroundStyle(.secondary)
                            .padding(.horizontal, 20).padding(.bottom, 7)
                    }
                    if let message = calendar.message {
                        HStack {
                            Text(message).friFont(.callout).fixedSize(horizontal: false, vertical: true).accessibilityLabel(message)
                            Spacer()
                            Button("Dismiss", systemImage: "xmark") { calendar.message = nil }.labelStyle(.iconOnly)
                        }
                        .padding(12).background(FRIColors.surface, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 18).padding(.bottom, 10)
                    }
                    if calendar.ready {
                        dateTabs
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                workspaceContent(wide: wide && geometry.size.width >= 1000)
                            }.padding(.horizontal, wide ? 26 : 16).padding(.vertical, 20)
                        }
                        #if os(macOS)
                        .focusable().focused($region, equals: 2)
                        #endif
                        .accessibilityIdentifier("fri.calendar.content")
                    } else if calendar.opening {
                        VStack(spacing: 12) {
                            ProgressView("Opening your calendar…")
                            Text("If macOS asks for Keychain access, review the system dialog to unlock your calendar.")
                                .friFont(.caption).foregroundStyle(.secondary)
                        }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ContentUnavailableView {
                            Label("Calendar unavailable", systemImage: "lock")
                        } actions: {
                            Button("Try Again") { calendar.open() }.buttonStyle(.borderedProminent)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .friFont(.body)
        .tint(FRIColors.accent)
        .foregroundStyle(FRIColors.ink)
        .background { FRIWindowBackdrop(enabled: glass).ignoresSafeArea() }
        .task {
            #if os(macOS)
            calendar.revealCalendar = {
                if let existing = NSApp.windows.first(where: { $0.identifier?.rawValue.hasPrefix("calendar-") == true }) {
                    existing.makeKeyAndOrderFront(nil)
                } else {
                    openWindow(id: "calendar")
                }
                NSApp.activate(ignoringOtherApps: true)
            }
            #endif
            calendar.open()
            #if DEBUG
            if ProcessInfo.processInfo.environment["FRI_WIDGET_PREVIEW"] == "1" { calendar.panel = .widget }
            #endif
        }
        .task(id: scenePhase == .active && calendar.appInForeground) {
            if scenePhase == .active && calendar.appInForeground {
                calendar.open()
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(3))
                    if calendar.ready, !Task.isCancelled { calendar.refreshIfChanged() }
                }
            }
        }
        #if os(macOS)
        .onChange(of: calendar.sidebarToggle) { showSidebar.toggle() }
        .onKeyPress(phases: .down) { key in
            guard calendar.ready, calendar.panel == nil, calendar.appointment == nil,
                  !showUsageGuide, !calendar.shortcutHelp, !keyboardNewMenu,
                  !(NSApp.keyWindow?.firstResponder is NSTextInputClient) else { return .ignored }
            if key.key.character == Character(UnicodeScalar(NSF6FunctionKey)!) {
                let visible = showSidebar && (NSApp.keyWindow?.contentView?.bounds.width ?? 0) >= 800 ? [0, 1, 2] : [1, 2]
                let current = region.flatMap { visible.firstIndex(of: $0) } ?? -1
                let next = (current + (key.modifiers.contains(.shift) ? visible.count - 1 : 1) + visible.count) % visible.count
                region = visible[next]
                return .handled
            }
            guard key.modifiers.intersection([.command, .control, .option]).isEmpty,
                  calendar.state.settings["singleKeys"]?.bool != false else { return .ignored }
            switch key.characters.lowercased() {
            case "n": keyboardNewMenu = true
            case "/": calendar.show(.search)
            case "t": calendar.select(CalendarClock.day())
            case "1": calendar.view = .day
            case "2": calendar.view = .week
            case "3": calendar.view = .month
            case "4": calendar.view = .year
            case "r": calendar.refreshSources()
            case "?": calendar.shortcutHelp = true
            default: return .ignored
            }
            return .handled
        }
        .confirmationDialog("New plan", isPresented: $keyboardNewMenu) {
            Button("Schedule") { calendar.newDraft(deadline: false) }
            Button("One-time deadline") { calendar.newDraft(deadline: true) }
            Button("Collection") { calendar.show(.collections) }
        }
        .sheet(isPresented: $calendar.shortcutHelp) {
            FRISheetView(title: "Keyboard shortcuts") {
                Form {
                    LabeledContent("Create a schedule", value: "⌘N")
                    LabeledContent("Search appointments", value: "⌘K · ⌘F · /")
                    LabeledContent("Settings · Sidebar", value: "⌘, · ⌘B")
                    LabeledContent("New plan · Today · Add ready plans", value: "N · T · R")
                    LabeledContent("Feed · Week · Month · Year", value: "1 · 2 · 3 · 4")
                    LabeledContent("Change region", value: "F6 · Shift F6")
                    LabeledContent("Confirm a plan", value: "⌘Return")
                }.formStyle(.grouped)
            }
        }
        .sheet(isPresented: $showUsageGuide, onDismiss: { calendar.presentFirstPlanIfReady() }) {
            VStack(spacing: 0) {
                if replayFirstPlan {
                    FRIFirstPlanWelcome { item in
                        calendar.prepareFirstPlan(item)
                        showUsageGuide = false
                    } explore: { showUsageGuide = false }
                } else {
                    Button("Thử tạo lịch từ tin nhắn mẫu") { replayFirstPlan = true }.padding(.top, 12)
                    FRIUsageGuide(reviewing: true) { showUsageGuide = false }
                .frame(minWidth: 500, idealWidth: 600, minHeight: 470, idealHeight: 570)
                .environment(\.dynamicTypeSize, effectiveType)
                }
            }.onDisappear { replayFirstPlan = false }
        }
        #else
        .onOpenURL { url in calendar.open(); calendar.openURL(url) }
        #endif
        .sheet(item: $calendar.panel, onDismiss: {
            #if os(macOS)
            calendar.firstPlan = nil
            #endif
            if let item = searchedAppointment {
                calendar.select(item.date)
                calendar.appointment = item
                searchedAppointment = nil
            }
        }) { panel in
            Group {
                switch panel {
                case .draft:
                    #if os(macOS)
                    FRIMacPlanEditor(calendar: calendar)
                    #else
                    FRIPlanEditorView(calendar: calendar)
                    #endif
                case .dayAssistant: FRIDayAssistantView(calendar: calendar)
                case .collections: FRICollectionsView(calendar: calendar)
                case .search: FRISearchView(tasks: calendar.state.tasks) { item in
                    searchedAppointment = item
                    calendar.panel = nil
                }
                case .manage: FRIManageView(tasks: dayTasks) { calendar.remove($0); calendar.panel = nil }
                case .importPlans: FRIImportView(calendar: calendar)
                case .widget: FRIWidgetHelpView(calendar: calendar)
                case .appearance: FRIAppearanceView(calendar: calendar)
                case .services: FRIServicesView(calendar: calendar, service: calendar.serviceToShow)
                case .planner: FRIPlannerView(calendar: calendar)
                case .availability: FRIAvailabilityView { action in
                    calendar.panel = nil
                    calendar.fileAction = action
                }
                }
            }
            .environment(\.dynamicTypeSize, effectiveType)
        }
        .sheet(item: $calendar.appointment) { item in
            FRIPlanDetailView(item: item, calendar: calendar)
                .environment(\.dynamicTypeSize, effectiveType)
        }
        .onChange(of: calendar.fileAction, initial: true) { _, action in
            guard let action else { return }
            calendar.fileAction = nil
            switch action {
            case .exportBackup:
                prepareExport(name: "FRI-backup") { try CalendarBackup.export(calendar.state) }
            case .exportAvailability:
                prepareExport(name: "FRI-free-time") { try Planning.Availability.export(calendar.state.tasks, day: calendar.state.active) }
            case .restoreBackup, .compareAvailability:
                pendingRead = action
                importing = true
            }
        }
        .fileExporter(isPresented: $exporting, document: fileExport, contentType: .json, defaultFilename: fileName) { result in
            do { _ = try result.get() }
            catch { calendar.message = error.localizedDescription }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let started = url.startAccessingSecurityScopedResource()
                defer { if started { url.stopAccessingSecurityScopedResource() } }
                let handle = try FileHandle(forReadingFrom: url)
                defer { try? handle.close() }
                let limit = pendingRead == .restoreBackup ? CalendarBackup.sizeLimit : 1_000_000
                let data = try handle.read(upToCount: limit + 1) ?? Data()
                if pendingRead == .restoreBackup { calendar.restoreCandidate = try CalendarBackup.read(data) }
                else {
                    let local = try Planning.Availability.export(calendar.state.tasks, day: calendar.state.active)
                    calendar.matchResults = try Planning.Availability.compare(local, data)
                }
            } catch { calendar.message = error.localizedDescription }
        }
        .alert("Restore calendar?", isPresented: Binding(get: { calendar.restoreCandidate != nil }, set: {
            if !$0 { calendar.restoreCandidate = nil }
        })) {
            Button("Cancel", role: .cancel) { calendar.restoreCandidate = nil }
            Button("Restore", role: .destructive) { calendar.restore() }
        } message: {
            Text("Replace the appointments, drafts and compatible settings with those in this backup.")
        }
        .sheet(isPresented: Binding(get: { calendar.matchResults != nil }, set: {
            if !$0 { calendar.matchResults = nil }
        })) {
            FRISheetView(title: "Shared free time") {
                List {
                    if calendar.matchResults?.isEmpty == true { Text("No shared slots of at least 30 minutes.") }
                    ForEach(calendar.matchResults ?? [], id: \.self) { slot in
                        VStack(alignment: .leading) {
                            Text(slot.start, format: .dateTime.weekday(.wide).month().day())
                            Text(slot.start...slot.end).friFont(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .environment(\.dynamicTypeSize, effectiveType)
        }
        // Keep the calendar aligned with the explicitly sized sheet content.
        .environment(\.dynamicTypeSize, effectiveType)
        .preferredColorScheme(calendar.state.settings["theme"]?.string == "dark" ? .dark : .light)
        .onChange(of: calendar.state.active) { feedDays = 14 }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("fri").font(.system(size: 48, weight: .semibold)).tracking(-4)
                        Text(".").font(.system(size: 48, weight: .semibold)).foregroundStyle(FRIColors.accent)
                        Spacer()
                        Button { calendar.panel = .search } label: {
                            Label("Search appointments", systemImage: "magnifyingglass").labelStyle(.iconOnly)
                                .frame(width: 44, height: 44)
                                .background(FRIColors.control, in: Circle()).contentShape(Rectangle())
                        }.help("Search appointments")
                    }.padding(.bottom, 8)
                    dayButtons.frame(maxWidth: .infinity).padding(5)
                        .background(FRIColors.control, in: RoundedRectangle(cornerRadius: 18))
                    newMenu.foregroundStyle(FRIColors.onAccent).frame(maxWidth: .infinity, alignment: .leading).padding(14)
                        .background(FRIColors.accent, in: RoundedRectangle(cornerRadius: 16))
                    Button { calendar.panel = .importPlans } label: {
                        Label("Sources", systemImage: "tray.full").frame(maxWidth: .infinity, alignment: .leading)
                    }.accessibilityIdentifier("fri.sources")
                    ForEach(calendar.state.sourceLibrary.prefix(5)) { source in
                        Button {
                            calendar.selectedSource = source.id
                            calendar.panel = .importPlans
                        } label: {
                            VStack(alignment: .leading) {
                                Text(source.label).lineLimit(1)
                                Text(calendar.state.importQueue.first { $0.id == source.id }.map { "\($0.rows.count) prepared" } ?? "Source saved")
                                    .friFont(.caption).foregroundStyle(FRIColors.muted)
                            }
                        }
                    }
                    Text("YOUR SPACE").friFont(.caption2, weight: .semibold).tracking(2).padding(.top, 12)
                    navigation
                    if !calendar.state.collections.isEmpty {
                        Text("COLLECTIONS").friFont(.caption2, weight: .semibold).tracking(2)
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(Set(calendar.state.collections.compactMap(\.string))).sorted(), id: \.self) { name in
                                Button {
                                    calendar.collection = calendar.collection == name ? nil : name
                                    calendar.view = .day
                                } label: {
                                    Label(name, systemImage: "folder").fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                                        .background(calendar.collection == name ? FRIColors.accent : .clear, in: RoundedRectangle(cornerRadius: 10))
                                }.accessibilityAddTraits(calendar.collection == name ? .isSelected : [])
                            }
                        }
                    }
                    Text("QUICK LINKS").friFont(.caption2, weight: .semibold).tracking(2).padding(.top, 10)
                    Button("Google Calendar", systemImage: "link") {
                        if let url = URL(string: "https://calendar.google.com") { openURL(url) }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("fri.sidebar.google")
                    .background(FRIColors.cloud, in: RoundedRectangle(cornerRadius: 13))
                    Button("A little focus music", systemImage: "music.note") { calendar.showService(.spotify) }
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("fri.sidebar.music")
                        .background(FRIColors.cloud, in: RoundedRectangle(cornerRadius: 13))
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("fri.sidebar.content")
            HStack {
                Button { calendar.showService() } label: {
                    Label("Services", systemImage: "square.grid.2x2")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }.accessibilityIdentifier("fri.sidebar.services")
                Button { calendar.panel = .appearance } label: {
                    Label("Settings", systemImage: "gearshape")
                        .labelStyle(.iconOnly).frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }.accessibilityIdentifier("fri.sidebar.settings")
            }.padding(12).background(FRIColors.control, in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain).padding(18)
        .foregroundStyle(FRIColors.ink)
        .background {
            FRIBackdropArtwork(mode: calendar.state.settings["sidebar"]?.string ?? "solid",
                               image: calendar.state.sidebarImageData,
                               motion: calendar.animateCalendar)
        }
        .overlay(alignment: .trailing) { Rectangle().fill(FRIColors.line.opacity(0.2)).frame(width: 1) }
    }

    private var navigation: some View {
        ForEach(FRICalendarSession.CalendarView.allCases, id: \.self) { view in
            Button { calendar.view = view; calendar.collection = nil } label: {
                HStack {
                    Label(view.rawValue,
                          systemImage: view == .day ? "square.grid.2x2" : (view == .month ? "calendar" : "calendar.badge.clock"))
                    Spacer(minLength: 0)
                    if view == .day { Text(dayTasks.count, format: .number).friFont(.caption) }
                }
                .padding(.vertical, 12).padding(.horizontal, 12)
                .foregroundStyle(calendar.view == view ? FRIColors.accent : FRIColors.ink)
                .background(calendar.view == view ? FRIColors.surface : FRIColors.cloud, in: RoundedRectangle(cornerRadius: 13))
            }
            .accessibilityIdentifier("fri.navigation.\(view.rawValue.lowercased())")
            .accessibilityAddTraits(calendar.view == view ? .isSelected : [])
        }
    }

    private var newMenu: some View {
        Menu {
            Button("Schedule", systemImage: "calendar") { calendar.newDraft(deadline: false) }
            Button("One-time deadline", systemImage: "flag") { calendar.newDraft(deadline: true) }
            Button("Collection", systemImage: "folder.badge.plus") { calendar.show(.collections) }
            if !calendar.state.drafts.isEmpty {
                Button("Resume drafts", systemImage: "doc") { calendar.newDraft(deadline: false) }
            }
        } label: { Label("New", systemImage: "plus") }
            .accessibilityIdentifier("fri.new")
    }

    private func toolbarIcon(_ title: String, systemImage: String) -> some View {
        let asset = ["magnifyingglass": "FriSymbolSearch", "plus": "FriSymbolPlus", "gearshape": "FriSymbolSettings", "calendar": "FriSymbolCalendar", "folder": "FriSymbolFolder"][systemImage]
        return Label {
            Text(title)
        } icon: {
            if let asset { Image(asset).resizable().scaledToFit().frame(width: 21, height: 21) }
            else { Image(systemName: systemImage) }
        }
            .labelStyle(.iconOnly)
            .frame(width: 44, height: 44)
            .foregroundStyle(FRIColors.ink)
            .background(FRIColors.control, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
    }

    private func toolbar(wide: Bool) -> some View {
        HStack(spacing: 10) {
            if wide {
                Button { showSidebar.toggle() } label: {
                    toolbarIcon("Sidebar", systemImage: "sidebar.left")
                }.help(showSidebar ? "Hide sidebar" : "Show sidebar")
                Spacer()
            } else {
                Menu {
                    navigation
                    Button("Sources", systemImage: "tray.full") { calendar.panel = .importPlans }
                    Button("Settings", systemImage: "gearshape") { calendar.panel = .appearance }
                    Button("Services", systemImage: "square.grid.2x2") { calendar.showService() }
                } label: {
                    Image("FRIMark").resizable().frame(width: 33, height: 33)
                        .frame(width: 44, height: 44)
                        .background(FRIColors.control, in: RoundedRectangle(cornerRadius: 12))
                        .contentShape(Rectangle()).accessibilityLabel("FRI navigation")
                }
                .accessibilityIdentifier("fri.navigation.menu")
                Spacer(minLength: 0)
            }
            Button { calendar.refreshSources() } label: {
                Label("Add ready plans", systemImage: "arrow.clockwise")
                    .frame(minHeight: 44)
            }.disabled(calendar.readingSource).accessibilityIdentifier("fri.sources.refresh")
            #if os(macOS)
            Button { showUsageGuide = true } label: {
                toolbarIcon("Hướng dẫn sử dụng FRI", systemImage: "book")
            }.accessibilityIdentifier("fri.guide.open").help("Hướng dẫn sử dụng FRI")
            #endif
            Button { calendar.panel = .search } label: {
                toolbarIcon("Search", systemImage: "magnifyingglass")
            }.accessibilityIdentifier("fri.search").help("Search appointments")
            Menu {
                Button("Import plans", systemImage: "tray.and.arrow.down") { calendar.panel = .importPlans }
                Button("Find time for a task", systemImage: "clock") { calendar.panel = .planner }
                Button("Find time together", systemImage: "person.2") { calendar.panel = .availability }
                Button("Manage appointments", systemImage: "checklist") { calendar.panel = .manage }
                Toggle("Still to do", isOn: $calendar.onlyPending)
                Divider()
                Button("Add FRI widget", systemImage: "square.grid.2x2") { calendar.panel = .widget }
                Button("Export backup", systemImage: "arrow.up.document") { calendar.fileAction = .exportBackup }
                Button("Restore backup", systemImage: "arrow.down.document") { calendar.fileAction = .restoreBackup }
                if calendar.canUndo { Button("Undo", systemImage: "arrow.uturn.left") { calendar.undo() } }
            } label: { toolbarIcon("Calendar actions", systemImage: "ellipsis") }
                .accessibilityIdentifier("fri.actions").help("Calendar actions")
            if !wide {
                newMenu.buttonStyle(.borderedProminent).tint(FRIColors.accent).foregroundStyle(FRIColors.onAccent)
            }

        }
        .friFont(.body).buttonStyle(.plain).tint(FRIColors.accent)
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(FRIColors.cloud)
        .disabled(!calendar.ready)
    }

    private var dateTabs: some View {
        let tabs = Array(Set(calendar.state.tabs + [calendar.state.active])).sorted()
        return ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(tabs, id: \.self) { key in
                    if let date = CalendarClock.date(key) {
                        HStack(spacing: 7) {
                            Button {
                                calendar.select(key)
                            } label: {
                                if key == CalendarClock.day() { Text("Today") }
                                else { Text(date, format: .dateTime.month(.abbreviated).day()) }
                            }.buttonStyle(.plain)
                                #if os(macOS)
                                .focused($focusedTab, equals: key)
                                .onKeyPress(phases: [.down, .repeat]) { press in
                                    guard let index = tabs.firstIndex(of: key) else { return .ignored }
                                    let next: String
                                    switch press.key {
                                    case .leftArrow: next = tabs[max(0, index - 1)]
                                    case .rightArrow: next = tabs[min(tabs.count - 1, index + 1)]
                                    case .home: next = tabs[0]
                                    case .end: next = tabs[tabs.count - 1]
                                    case .delete, .deleteForward:
                                        guard key != CalendarClock.day() else { return .ignored }
                                        calendar.closeTab(key)
                                        focusedTab = calendar.state.active
                                        return .handled
                                    default: return .ignored
                                    }
                                    calendar.select(next)
                                    focusedTab = next
                                    return .handled
                                }
                                #endif
                                .accessibilityIdentifier("fri.tab.\(key)")
                                .accessibilityAddTraits(key == calendar.state.active ? .isSelected : [])
                            if key != CalendarClock.day() {
                                Button("Close date tab", systemImage: "xmark") { calendar.closeTab(key) }
                                    .labelStyle(.iconOnly).buttonStyle(.plain)
                            }
                        }
                        .friFont(.subheadline, weight: .medium)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .foregroundStyle(key == calendar.state.active ? FRIColors.ink : FRIColors.muted)
                        .background(key == calendar.state.active ? FRIColors.surface : FRIColors.control,
                                    in: UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14))
                    }
                }
                Button("Open another day", systemImage: "plus") { calendar.view = .month }
                    .labelStyle(.iconOnly).buttonStyle(.plain).padding(12)
            }.padding(.horizontal, 18).padding(.top, 4)
        }.scrollIndicators(.hidden).background(FRIColors.cloud)
    }

    private func workspaceContent(wide: Bool) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                dayHeading
                ring
            }
            ViewThatFits(in: .horizontal) {
                HStack {
                    viewSelector
                    Spacer()
                    appointmentFilters
                }
                VStack(alignment: .leading, spacing: 10) {
                    viewSelector
                    appointmentFilters
                }
            }
            if wide && !effectiveType.isAccessibilitySize {
                HStack(alignment: .top, spacing: 20) {
                    calendarContents
                    upNext.frame(width: 200)
                }
            } else {
                calendarContents
                upNext
            }
        }
    }

    @ViewBuilder private var calendarContents: some View {
        if calendar.view == .day { appointments }
        else {
            FRICalendarGridView(mode: calendar.view, cursor: $calendar.cursor,
                                tasks: calendar.state.tasks, select: calendar.select, open: { calendar.appointment = $0 }) { date in
                calendar.cursor = date
                calendar.view = .month
            }
        }
    }

    private var viewSelector: some View {
        Picker("Calendar view", selection: $calendar.view) {
            ForEach(FRICalendarSession.CalendarView.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }.pickerStyle(.menu).labelsHidden().accessibilityIdentifier("fri.view.selector")
    }

    private var appointmentFilters: some View {
        ViewThatFits(in: .horizontal) {
            HStack { collectionFilter; pendingFilter }
            VStack(alignment: .leading) { collectionFilter; pendingFilter }
        }
    }

    private var collectionFilter: some View {
        Menu {
            Button("All collections") { calendar.collection = nil }
            ForEach(Array(Set(calendar.state.collections.compactMap(\.string))).sorted(), id: \.self) { name in
                Button(name) { calendar.collection = name }
            }
            Button("New collection…") { calendar.show(.collections) }
        } label: { Label(calendar.collection ?? "Collections", systemImage: "folder") }
        .accessibilityIdentifier("fri.collections")
    }

    private var pendingFilter: some View {
        Button(calendar.onlyPending ? "Still to do" : "All plans", systemImage: "line.3.horizontal.decrease") {
            calendar.onlyPending.toggle()
        }.buttonStyle(.plain).padding(10)
            .background(FRIColors.cloud, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("fri.filter")
    }

    private var visibleFeedIDs: [String] {
        let last = CalendarClock.local.date(byAdding: .day, value: feedDays, to: selected) ?? selected
        let start = CalendarClock.day(selected), end = CalendarClock.day(last)
        return calendar.state.tasks.filter {
            $0.date >= start && $0.date < end && (!calendar.onlyPending || !$0.done)
                && (calendar.collection == nil || $0.category == calendar.collection)
        }.sorted { ($0.date, $0.time, $0.id) < ($1.date, $1.time, $1.id) }.map(\.id)
    }

    private var appointments: some View {
        let clock = CalendarClock.local
        let groups = Dictionary(grouping: calendar.state.tasks, by: \.date)
        return LazyVStack(alignment: .leading, spacing: 12) {
            if (calendar.onlyPending || calendar.collection != nil) && visibleFeedIDs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No appointments match this view.")
                    Button("Show all plans") {
                        calendar.onlyPending = false
                        calendar.collection = nil
                    }
                }.padding(14).modifier(FRISurface(glass: false, radius: 14))
            }
            ForEach(0..<feedDays, id: \.self) { offset in
                if let date = clock.date(byAdding: .day, value: offset, to: selected) {
                    let key = CalendarClock.day(date)
                    let daily = (groups[key] ?? []).sorted { ($0.time, $0.id) < ($1.time, $1.id) }
                    let rows = daily.filter { (!calendar.onlyPending || !$0.done) && (calendar.collection == nil || $0.category == calendar.collection) }
                    if offset < 2 || !rows.isEmpty {
                        HStack {
                            Text(clock.isDateInToday(date) ? "Today" : clock.isDateInTomorrow(date) ? "Tomorrow" : date.formatted(.dateTime.weekday(.wide)))
                                .friFont(.headline)
                            Text(date, format: .dateTime.month(.abbreviated).day()).foregroundStyle(FRIColors.muted)
                            Spacer()
                            Text(rows.count == 1 ? "1 plan" : "\(rows.count) plans").friFont(.caption)
                        }.padding(.top, 8).accessibilityAddTraits(.isHeader)
                        if rows.isEmpty {
                            HStack {
                                Text("Nothing planned").foregroundStyle(FRIColors.muted)
                                Spacer()
                                Button("Add a plan") { calendar.select(key); calendar.newDraft(deadline: false) }
                            }.padding(14).modifier(FRISurface(glass: false, radius: 14))
                        }
                        ForEach(rows) { item in
                            FRICardView(item: item, overlaps: item.conflict(in: daily) != nil,
                                        show: { calendar.appointment = item },
                                        complete: {
                                            if calendar.onlyPending, !item.done {
                                                let ids = visibleFeedIDs
                                                if let i = ids.firstIndex(of: item.id) {
                                                    let fallback = ids.dropFirst(i + 1).first ?? ids.prefix(i).last
                                                    feedFocus = fallback.map(FeedFocus.details)
                                                }
                                            }
                                            calendar.setDoneWithoutOpening(item)
                                        }, focus: $feedFocus)
                                .id(item.id)
                                .onKeyPress(phases: [.down, .repeat]) { key in
                                    let ids = visibleFeedIDs
                                    guard let i = ids.firstIndex(of: item.id) else { return .ignored }
                                    switch key.key {
                                    case .upArrow: feedFocus = .details(ids[max(0, i - 1)])
                                    case .downArrow: feedFocus = .details(ids[min(ids.count - 1, i + 1)])
                                    case .home: feedFocus = .details(ids[0])
                                    case .end: feedFocus = .details(ids[ids.count - 1])
                                    case .leftArrow: feedFocus = .details(item.id)
                                    case .rightArrow: feedFocus = .completion(item.id)
                                    default: return .ignored
                                    }
                                    return .handled
                                }
                        }
                    }
                }
            }
            Button("Show the next two weeks", systemImage: "chevron.down") { feedDays += 14 }
                .frame(maxWidth: .infinity).padding(10)
        }
    }

    private var dayHeading: some View {
        Button { calendar.view = .month; calendar.cursor = selected } label: {
            VStack(alignment: .leading, spacing: 7) {
                Text(selected, format: .dateTime.weekday(.wide))
                    .friFont(.largeTitle, weight: .semibold).minimumScaleFactor(0.75).lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                HStack {
                    Text(selected, format: .dateTime.month(.wide).day().year())
                        .friFont(.subheadline).foregroundStyle(FRIColors.muted).fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Image(systemName: "calendar")
                }
            }.padding(16).frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
                .modifier(FRISurface(glass: false, radius: 16))
        }.buttonStyle(.plain).accessibilityLabel("Open month calendar")
            .accessibilityValue(Text(selected, format: .dateTime.weekday(.wide).month(.wide).day().year()))
    }

    private var upNext: some View {
        VStack(spacing: 14) {
            ForEach(Array(calendar.state.widgets.enumerated()), id: \.offset) { _, value in
                if value.string == "upnext" {
                    upNextCard
                } else if let key = value.string, let service = FRIService(rawValue: key) {
                    FRIServiceCardsView(calendar: calendar, service: service)
                }
            }
            Button("Add a widget", systemImage: "plus") { calendar.panel = .widget }
                .buttonStyle(.plain).padding(14).frame(maxWidth: .infinity)
                .background(FRIColors.cloud, in: RoundedRectangle(cornerRadius: 14))
            Button { calendar.panel = .dayAssistant } label: {
                VStack(spacing: 8) {
                    FRIDayWave(motion: calendar.animateCalendar).frame(width: 56, height: 56)
                    Text("Meet Day").friFont(.caption)
                }.frame(maxWidth: .infinity)
            }.buttonStyle(.plain).accessibilityLabel("Talk to Day")
        }
    }

    private var upNextCard: some View {
        let nextID = WidgetSnapshot(state: calendar.state, day: selected, now: .now).tasks.first?.id
        let next = dayTasks.first { $0.id == nextID }
        return
            VStack(alignment: .leading, spacing: 22) {
                HStack { Text("UP NEXT").friFont(.caption2, weight: .semibold).tracking(2); Spacer(); Image(systemName: "clock") }
                if let next {
                    Button { calendar.appointment = next } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(next.time).friFont(.title, weight: .medium)
                            Text(next.title).friFont(.title3, weight: .semibold).fixedSize(horizontal: false, vertical: true)
                            if !next.location.isEmpty { Label(next.location, systemImage: "mappin").friFont(.caption) }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.plain)
                    Button(next.done ? "Completed" : "Done", systemImage: "checkmark.circle") { calendar.setDoneWithoutOpening(next) }
                        .buttonStyle(.bordered).tint(FRIColors.accent)
                } else {
                    Rectangle().fill(FRIColors.line).frame(height: 3)
                    Text(dayTasks.isEmpty ? "A fresh page." : "Room to breathe.").friFont(.title2, weight: .medium)
                        .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("fri.upNext.emptyTitle")
                    Text(dayTasks.isEmpty ? "Your next appointment will find a home here." : "You have finished every appointment. Enjoy this little moment.").friFont(.callout).foregroundStyle(FRIColors.muted)
                        .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("fri.upNext.emptyMessage")
                }
                ViewThatFits(in: .horizontal) {
                    HStack {
                        upNextRemaining
                        Spacer(minLength: 8)
                        upNextToggle
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        upNextRemaining
                        upNextToggle
                    }
                }
                if showUpcoming {
                    ForEach(dayTasks.filter { !$0.done && $0.id != nextID }) { item in
                        Button { calendar.appointment = item } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title).friFont(.callout, weight: .medium)
                                Text(item.time).friFont(.caption).foregroundStyle(FRIColors.muted)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.plain)
                    }
                }
            }.padding(20).frame(maxWidth: .infinity, minHeight: 240, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)
                .modifier(FRISurface(glass: glass, radius: 26))
                .accessibilityElement(children: .contain).accessibilityIdentifier("fri.upNext.card")
    }

    private var upNextRemaining: some View {
        Text("\(dayTasks.count - complete) remaining").friFont(.caption).fixedSize()
            .accessibilityIdentifier("fri.upNext.remaining")
    }

    private var upNextToggle: some View {
        Button { showUpcoming.toggle() } label: {
            Text(showUpcoming ? "Less" : "Coming up").friFont(.caption).fixedSize()
                .frame(minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(FRIColors.muted)
            .accessibilityIdentifier("fri.upNext.toggle")
            .accessibilityValue(showUpcoming ? "Expanded" : "Collapsed")
    }

    private var dayButtons: some View {
        HStack(spacing: 8) {
            Button("Previous day", systemImage: "chevron.left") { moveDay(-1) }.labelStyle(.iconOnly)
            Button("Today") { calendar.select(CalendarClock.day()) }
            Button("Next day", systemImage: "chevron.right") { moveDay(1) }.labelStyle(.iconOnly)
        }.buttonStyle(.plain).tint(FRIColors.accent)
    }

    @ViewBuilder private var ring: some View {
        if complete > 0, complete == dayTasks.count, !finished {
            Button {
                let day = calendar.state.active
                _ = calendar.change { state in
                    let appointments = state.tasks(on: day)
                    if !appointments.isEmpty, appointments.allSatisfy(\.done),
                       !state.finished.contains(.string(day)) { state.finished.append(.string(day)) }
                }
            } label: { progressRing }
            .buttonStyle(.plain)
            .accessibilityLabel("Finish day")
        } else {
            progressRing.accessibilityLabel(finished ? "Day complete" : "\(complete) of \(dayTasks.count) appointments done")
        }
    }

    private var progressRing: some View {
        ZStack {
            Circle().strokeBorder(.primary.opacity(0.12), lineWidth: 4)
            Circle().trim(from: 0, to: dayTasks.isEmpty ? 0 : CGFloat(complete) / CGFloat(dayTasks.count))
                .stroke(.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90)).padding(2)
            if finished { Image(systemName: "checkmark").friFont(.body, weight: .semibold) }
            else { Text("\(complete)/\(dayTasks.count)").friFont(.caption).monospacedDigit() }
        }
        .frame(width: 64, height: 64).padding(5)
        .foregroundStyle(FRIColors.accent)
        .background(FRIColors.surface, in: Circle())
        .accessibilityIdentifier("fri.day.progress")
    }

    private func moveDay(_ offset: Int) {
        guard let day = CalendarClock.local.date(byAdding: .day, value: offset, to: selected) else { return }
        calendar.select(CalendarClock.day(day))
    }

    private func prepareExport(name: String, data: () throws -> Data) {
        do {
            fileName = name
            fileExport = FRIFile(data: try data())
            exporting = true
        } catch { calendar.message = error.localizedDescription }
    }
}

struct FRIFile: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

private enum FeedFocus: Hashable {
    case details(String), completion(String)
}

private struct FRICardView: View {
    let item: Appointment
    let overlaps: Bool
    let show: () -> Void
    let complete: () -> Void
    let focus: FocusState<FeedFocus?>.Binding

    var body: some View {
        HStack(spacing: 12) {
            Button(action: show) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.time).friFont(.headline).monospacedDigit()
                        if item.duration > 0 { Text("\(item.duration) min").friFont(.caption).foregroundStyle(FRIColors.muted) }
                    }.frame(minWidth: 53, alignment: .leading)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.isDeadline ? "Deadline" : item.category).friFont(.caption, weight: .semibold)
                            .foregroundStyle(FRIColors.accent)
                        Text(item.title).friFont(.headline).strikethrough(item.done)
                        if !item.location.isEmpty { Text(item.location).friFont(.caption).foregroundStyle(FRIColors.muted) }
                        if overlaps { Label("Time overlap", systemImage: "clock.badge.exclamationmark").friFont(.caption) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.contentShape(Rectangle())
            }.focused(focus, equals: .details(item.id)).accessibilityIdentifier("fri.card.\(item.id)")
            Button(action: complete) {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.title2).foregroundStyle(FRIColors.accent).frame(width: 44, height: 44).contentShape(Rectangle())
            }.focused(focus, equals: .completion(item.id)).accessibilityLabel(item.done ? "Mark as pending" : "Done").accessibilityIdentifier("fri.done.\(item.id)")
        }.buttonStyle(.plain).padding(14).modifier(FRISurface(glass: false, radius: 16))
    }
}

struct FRIDayWave: View {
    var motion = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var phase
    var body: some View {
        let paused = !motion || reduceMotion || phase != .active
        if paused {
            wave(offset: 0)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 20)) { timeline in
                wave(offset: sin(timeline.date.timeIntervalSinceReferenceDate * 2 * .pi / 8) * 0.17)
            }.accessibilityHidden(true)
        }
    }

    private func wave(offset: Double) -> some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            context.clip(to: Path(ellipseIn: CGRect(origin: .zero, size: size)))
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.09, green: 0.17, blue: 0.23)))
            var wave = Path()
            wave.move(to: CGPoint(x: 0, y: h * 0.58))
            wave.addCurve(to: CGPoint(x: w, y: h * 0.42), control1: CGPoint(x: w * 0.38, y: h * (0.12 + offset)),
                          control2: CGPoint(x: w * 0.58, y: h * (0.86 - offset)))
            wave.addLine(to: CGPoint(x: w, y: h)); wave.addLine(to: CGPoint(x: 0, y: h)); wave.closeSubpath()
            context.fill(wave, with: .color(FRIColors.accent))
        }.accessibilityHidden(true)
    }
}
