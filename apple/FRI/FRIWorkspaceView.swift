import FRICore
import FRIDesign
import SwiftUI
import UniformTypeIdentifiers

struct FRIWorkspaceView: View {
    @Bindable var calendar: FRICalendarSession
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var typeSize
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
    private var visible: [Appointment] {
        dayTasks.filter { (!calendar.onlyPending || !$0.done) && (calendar.collection == nil || $0.category == calendar.collection) }
    }
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
                if wide && showSidebar { sidebar.frame(width: 235) }
                VStack(alignment: .leading, spacing: 0) {
                    toolbar(wide: wide)
                    if calendar.synthetic {
                        Text("Development preview · sample data only")
                            .friFont(.caption).foregroundStyle(.secondary)
                            .padding(.horizontal, 20).padding(.bottom, 7)
                    }
                    if let message = calendar.message {
                        HStack {
                            Text(message).friFont(.callout)
                            Spacer()
                            Button("Dismiss", systemImage: "xmark") { calendar.message = nil }.labelStyle(.iconOnly)
                        }
                        .padding(12).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 18).padding(.bottom, 10)
                    }
                    if calendar.ready {
                        dateTabs
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                workspaceContent(wide: wide && geometry.size.width >= 1000)
                            }.padding(.horizontal, wide ? 26 : 16).padding(.vertical, 20)
                        }
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
        .tint(FRIColors.marsala)
        .foregroundStyle(FRIColors.cream)
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
        .task(id: scenePhase) {
            if scenePhase == .active {
                calendar.open()
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(3))
                    if calendar.ready, !Task.isCancelled { calendar.refreshIfChanged() }
                }
            }
        }
        .onOpenURL { url in calendar.open(); calendar.openURL(url) }
        .sheet(item: $calendar.panel, onDismiss: {
            if let item = searchedAppointment {
                calendar.select(item.date)
                calendar.appointment = item
                searchedAppointment = nil
            }
        }) { panel in
            Group {
                switch panel {
                case .draft: FRIPlanEditorView(calendar: calendar)
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
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("fri").font(.system(size: 48, weight: .semibold)).tracking(-4)
                        Text(".").font(.system(size: 48, weight: .semibold)).foregroundStyle(FRIColors.marsala)
                        Spacer()
                        Button { calendar.panel = .search } label: {
                            Label("Search appointments", systemImage: "magnifyingglass").labelStyle(.iconOnly)
                                .frame(width: 44, height: 44)
                                .background(FRIColors.control, in: Circle()).contentShape(Rectangle())
                        }.help("Search appointments")
                    }.padding(.bottom, 8)
                    dayButtons.frame(maxWidth: .infinity).padding(5)
                        .background(FRIColors.control, in: RoundedRectangle(cornerRadius: 18))
                    newMenu.frame(maxWidth: .infinity, alignment: .leading).padding(14)
                        .background(FRIColors.marsala, in: RoundedRectangle(cornerRadius: 16))
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
                                        .background(calendar.collection == name ? FRIColors.marsala : .clear, in: RoundedRectangle(cornerRadius: 10))
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
                    .background(FRIColors.sidebar, in: RoundedRectangle(cornerRadius: 13))
                    Button("A little focus music", systemImage: "music.note") { calendar.showService(.spotify) }
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("fri.sidebar.music")
                        .background(FRIColors.sidebar, in: RoundedRectangle(cornerRadius: 13))
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
        .foregroundStyle(FRIColors.cream)
        .background {
            FRIBackdropArtwork(mode: calendar.state.settings["sidebar"]?.string ?? "gradient",
                               image: calendar.state.sidebarImageData,
                               motion: calendar.state.settings["motion"]?.bool != false)
        }
        .overlay(alignment: .trailing) { Rectangle().fill(FRIColors.line.opacity(0.2)).frame(width: 1) }
    }

    private var navigation: some View {
        ForEach(FRICalendarSession.CalendarView.allCases, id: \.self) { view in
            Button { calendar.view = view; calendar.collection = nil } label: {
                HStack {
                    Label(view == .day ? "My day" : view.rawValue,
                          systemImage: view == .day ? "square.grid.2x2" : (view == .month ? "calendar" : "calendar.badge.clock"))
                    Spacer(minLength: 0)
                    if view == .day { Text(dayTasks.count, format: .number).friFont(.caption) }
                }
                .padding(.vertical, 12).padding(.horizontal, 12)
                .foregroundStyle(calendar.view == view ? FRIColors.ink : FRIColors.cream)
                .background(calendar.view == view ? FRIColors.cream : FRIColors.sidebar, in: RoundedRectangle(cornerRadius: 13))
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
        Label(title, systemImage: systemImage)
            .labelStyle(.iconOnly)
            .frame(width: 44, height: 44)
            .foregroundStyle(FRIColors.cream)
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
                newMenu.buttonStyle(.borderedProminent).tint(FRIColors.marsala).foregroundStyle(FRIColors.cream)
            }

        }
        .friFont(.body).buttonStyle(.plain).tint(FRIColors.cream)
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(FRIColors.sidebar)
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
                                .accessibilityIdentifier("fri.tab.\(key)")
                                .accessibilityAddTraits(key == calendar.state.active ? .isSelected : [])
                            if key != CalendarClock.day() {
                                Button("Close date tab", systemImage: "xmark") { calendar.closeTab(key) }
                                    .labelStyle(.iconOnly).buttonStyle(.plain)
                            }
                        }
                        .friFont(.subheadline, weight: .medium)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .foregroundStyle(key == calendar.state.active ? FRIColors.ink : FRIColors.cream)
                        .background(key == calendar.state.active ? FRIColors.cream : FRIColors.control,
                                    in: UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14))
                    }
                }
                Button("Open another day", systemImage: "plus") { calendar.view = .month }
                    .labelStyle(.iconOnly).buttonStyle(.plain).padding(12)
            }.padding(.horizontal, 18).padding(.top, 4)
        }.scrollIndicators(.hidden).background(FRIColors.sidebar)
    }

    private func workspaceContent(wide: Bool) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                    dayHeading.frame(minWidth: 180, maxWidth: .infinity)
                    headingActions(compact: false).frame(width: 110)
                    ring.frame(width: 100)
                }.frame(minHeight: 174)
                HStack(spacing: 12) {
                    dayHeading.frame(minWidth: 200, idealWidth: 200, maxWidth: .infinity)
                    VStack(spacing: 12) {
                        ring
                        headingActions(compact: true)
                    }.frame(width: 100)
                }
                VStack(spacing: 14) {
                    dayHeading
                    HStack { headingActions(compact: false); Spacer(); ring }
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack {
                    if calendar.view == .day { Text("Appointments").friFont(.headline).accessibilityAddTraits(.isHeader) }
                    Spacer()
                    appointmentFilters
                }
                VStack(alignment: .leading, spacing: 10) {
                    if calendar.view == .day { Text("Appointments").friFont(.headline).accessibilityAddTraits(.isHeader) }
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
                                tasks: calendar.state.tasks, select: calendar.select) { date in
                calendar.cursor = date
                calendar.view = .month
            }
        }
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
            .background(FRIColors.sidebar, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("fri.filter")
    }

    @ViewBuilder private var appointments: some View {
        if visible.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "leaf").friFont(.largeTitle)
                Text(dayTasks.isEmpty ? "This day is yours." : "A little breathing room.").friFont(.title2, weight: .semibold)
                if dayTasks.isEmpty {
                    Text("Start with one thing you would love to make time for.")
                        .foregroundStyle(FRIColors.muted).multilineTextAlignment(.center)
                    Button("Add an appointment") { calendar.newDraft(deadline: false) }
                        .buttonStyle(.borderedProminent).tint(FRIColors.marsala).foregroundStyle(FRIColors.cream)
                } else {
                    Text("No appointments match this view.").foregroundStyle(FRIColors.muted)
                    Button("Show all plans") { calendar.onlyPending = false; calendar.collection = nil }
                        .buttonStyle(.borderedProminent).tint(FRIColors.marsala).foregroundStyle(FRIColors.cream)
                }
            }
            .padding(30).frame(maxWidth: .infinity, minHeight: 245)
            .modifier(FRISurface(glass: glass, radius: 28))
        } else {
            FRIMosaic(durations: visible.map(\.duration), largeText: effectiveType.isAccessibilitySize || calendar.state.settings["large"]?.bool == true,
                      list: calendar.state.settings["layout"]?.string == "list") {
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, item in
                    FRICardView(item: item, glass: glass, accented: index % 3 == 1,
                                list: calendar.state.settings["layout"]?.string == "list", show: { calendar.appointment = item },
                                complete: { calendar.setDoneWithoutOpening(item) })
                }
            }
        }
    }

    private func headingActions(compact: Bool) -> some View {
        let layout = compact ? AnyLayout(HStackLayout(spacing: 8)) : AnyLayout(VStackLayout(spacing: 12))
        return layout {
            Button { calendar.newDraft(deadline: false) } label: {
                Group {
                    if compact { Label("Add", systemImage: "plus").labelStyle(.iconOnly) }
                    else { Label("Add", systemImage: "plus") }
                }.friFont(.title2)
                    .frame(maxWidth: .infinity, minHeight: compact ? 48 : 68).contentShape(Rectangle())
            }.background(FRIColors.marsala, in: RoundedRectangle(cornerRadius: compact ? 14 : 24))
                .accessibilityIdentifier("fri.day.add").help("Add an appointment")
            Button { calendar.panel = .manage } label: {
                Label("Manage appointments", systemImage: "ellipsis").labelStyle(.iconOnly)
                    .friFont(.title2).frame(maxWidth: .infinity, minHeight: compact ? 48 : 68).contentShape(Rectangle())
            }.background(FRIColors.sidebar, in: RoundedRectangle(cornerRadius: compact ? 14 : 24))
                .accessibilityIdentifier("fri.day.manage").help("Manage appointments")
        }.buttonStyle(.plain)
    }

    private var dayHeading: some View {
        Button { calendar.view = .month; calendar.cursor = selected } label: {
            VStack(alignment: .leading, spacing: 22) {
                Text(selected, format: .dateTime.weekday(.wide))
                    .font(.system(size: 42, weight: .medium)).minimumScaleFactor(0.75).lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                HStack {
                    Text(selected, format: .dateTime.month(.wide).day().year())
                        .friFont(.subheadline).foregroundStyle(FRIColors.muted).fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Image(systemName: "calendar")
                }
            }.padding(24).frame(maxWidth: .infinity, minHeight: 174, alignment: .leading)
                .modifier(FRISurface(glass: glass, radius: 26))
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
                .background(FRIColors.sidebar, in: RoundedRectangle(cornerRadius: 14))
            Button { calendar.panel = .dayAssistant } label: {
                VStack(spacing: 8) {
                    Image("DayBackdrop").resizable().scaledToFit().frame(maxWidth: 150, maxHeight: 150)
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
                        .buttonStyle(.bordered).tint(FRIColors.marsala)
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
        }.buttonStyle(.plain).tint(FRIColors.cream)
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
        .frame(width: 86, height: 86).padding(7)
        .background(FRIColors.sidebar, in: Circle())
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

private struct FRICardView: View {
    let item: Appointment
    let glass: Bool
    let accented: Bool
    let list: Bool
    let show: () -> Void
    let complete: () -> Void

    private var fill: Color { item.done ? FRIColors.completed : (accented ? FRIColors.marsala : FRIColors.cream) }
    private var ink: Color { item.done ? Color(red: 107 / 255, green: 92 / 255, blue: 84 / 255) : (accented ? .white : FRIColors.ink) }
    private var timeParts: (main: String, period: String) {
        let minutes = CalendarClock.minutes(item.time) ?? 0
        let hour = minutes / 60
        return (String(format: "%d:%02d", hour % 12 == 0 ? 12 : hour % 12, minutes % 60), hour >= 12 ? "PM" : "AM")
    }
    private var duration: String {
        if item.isDeadline { return "Deadline" }
        if item.duration < 60 { return "\(item.duration)m" }
        return "\(item.duration / 60)h" + (item.duration % 60 == 0 ? "" : " \(item.duration % 60)m")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: show) {
                VStack(alignment: .leading, spacing: 12) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(item.isDeadline ? "Deadline" : item.category).textCase(.uppercase)
                            Spacer(minLength: 5)
                            Text(duration)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.isDeadline ? "Deadline" : item.category).textCase(.uppercase)
                            Text(duration)
                        }
                    }.friFont(.caption).opacity(0.8)
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(timeParts.main).font(.system(size: list ? 28 : 31, weight: .regular).monospacedDigit())
                        Text(timeParts.period).friFont(.caption)
                    }.opacity(item.done ? 0.7 : 1)
                    if !list { Spacer(minLength: 18) }
                    Text(item.title).friFont(.headline).strikethrough(item.done)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(item.location.isEmpty ? "A place of your choosing" : item.location)
                        .friFont(.caption).opacity(0.8).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
            }.buttonStyle(.plain)
                .accessibilityIdentifier("fri.card.\(item.id)")
                .accessibilityLabel("\(item.title), \(item.time), \(item.isDeadline ? "Deadline" : "\(item.duration) min"), \(item.location)")
            HStack {
                Spacer(minLength: 0)
                Button(action: complete) {
                    ZStack {
                        Circle().fill(item.done ? FRIColors.marsala : (accented ? FRIColors.cream : Color(red: 231 / 255, green: 220 / 255, blue: 213 / 255)))
                        Circle().strokeBorder(item.done || accented ? .clear : Color(red: 188 / 255, green: 165 / 255, blue: 156 / 255))
                        if item.done { Image(systemName: "checkmark").font(.system(size: 16, weight: .semibold)).foregroundStyle(FRIColors.cream) }
                    }.frame(width: 36, height: 36)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.done ? "Mark as pending" : "Done")
                .accessibilityIdentifier("fri.done.\(item.id)")
            }.padding(.horizontal, 13).padding(.bottom, 9)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(FRISurface(glass: glass, radius: 24, fill: fill, text: ink,
                             border: accented && !item.done ? FRIColors.marsala : Color(red: 227 / 255, green: 217 / 255, blue: 209 / 255)))
    }
}
