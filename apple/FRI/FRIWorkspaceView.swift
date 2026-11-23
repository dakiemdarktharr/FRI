import FRICore
import FRIDesign
import SwiftUI
import UniformTypeIdentifiers

struct FRIWorkspaceView: View {
    @Bindable var calendar: FRICalendarSession
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showSidebar = true
    @State private var fileExport: FRIFile?
    @State private var exporting = false
    @State private var importing = false
    @State private var fileName = "FRI-backup"
    @State private var pendingRead: FRICalendarSession.FileAction?
    @State private var searchedAppointment: Appointment?

    private var selected: Date { CalendarClock.date(calendar.state.active) ?? .now }
    private var dayTasks: [Appointment] { calendar.state.tasks(on: calendar.state.active) }
    private var visible: [Appointment] { dayTasks.filter { !calendar.onlyPending || !$0.done } }
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
                if wide && showSidebar { sidebar.frame(width: 218) }
                VStack(alignment: .leading, spacing: 0) {
                    toolbar(wide: wide)
                    if calendar.synthetic {
                        Text("Development preview · sample data only")
                            .font(.caption).foregroundStyle(.secondary)
                            .padding(.horizontal, 20).padding(.bottom, 7)
                    }
                    if let message = calendar.message {
                        HStack {
                            Text(message).font(.callout)
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
                                if calendar.view == .day { day }
                                else {
                                    FRICalendarGridView(mode: calendar.view, cursor: $calendar.cursor,
                                                        tasks: calendar.state.tasks, select: calendar.select) { date in
                                        calendar.cursor = date
                                        calendar.view = .month
                                    }
                                }
                            }.padding(.horizontal, wide ? 26 : 16).padding(.vertical, 20)
                        }
                        .accessibilityIdentifier("fri.calendar.content")
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
        .tint(colorScheme == .dark ? .white : .black)
        .environment(\.dynamicTypeSize, effectiveType)
        .background { FRIWindowBackdrop(enabled: glass).ignoresSafeArea() }
        .task {
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
            switch panel {
            case .draft: FRIPlanEditorView(calendar: calendar)
            case .search: FRISearchView(tasks: calendar.state.tasks) { item in
                searchedAppointment = item
                calendar.panel = nil
            }
            case .manage: FRIManageView(tasks: dayTasks) { calendar.remove($0); calendar.panel = nil }
            case .importPlans: FRIImportView(calendar: calendar)
            case .widget: FRIWidgetHelpView(calendar: calendar)
            case .appearance: FRIAppearanceView(calendar: calendar)
            case .services: FRIServicesView(calendar: calendar)
            case .planner: FRIPlannerView(calendar: calendar)
            case .availability: FRIAvailabilityView { action in
                calendar.panel = nil
                calendar.fileAction = action
            }
            }
        }
        .sheet(item: $calendar.appointment) { item in
            FRIPlanDetailView(item: item, calendar: calendar)
        }
        .onChange(of: calendar.fileAction) { _, action in
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
                            Text(slot.start...slot.end).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image("FRIMark").resizable().frame(width: 29, height: 29).accessibilityHidden(true)
                Text("FRI").font(.system(.title, design: .rounded, weight: .black))
                Spacer()
            }
            .padding(.bottom, 12)
            navigation
            Spacer(minLength: 20)
            Button { calendar.panel = .services } label: {
                Label("Services", systemImage: "square.grid.2x2")
            }
            Button { calendar.panel = .appearance } label: {
                Label("Settings", systemImage: "gearshape")
            }
        }.buttonStyle(.plain).padding(20)
        .background {
            FRIBackdropArtwork(mode: calendar.state.settings["sidebar"]?.string ?? "gradient",
                               image: calendar.state.settings["appleSidebarImage"]?.string,
                               motion: calendar.state.settings["motion"]?.bool != false)
        }
        .overlay(alignment: .trailing) { Rectangle().fill(.primary.opacity(0.08)).frame(width: 1) }
    }

    private var navigation: some View {
        ForEach(FRICalendarSession.CalendarView.allCases, id: \.self) { view in
            Button { calendar.view = view } label: {
                HStack {
                    Label(view.rawValue, systemImage: view == .day ? "rectangle" : (view == .month ? "calendar" : "square.grid.2x2"))
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 10).padding(.horizontal, 12)
                .background(.primary.opacity(calendar.view == view ? 0.12 : 0), in: RoundedRectangle(cornerRadius: 9))
            }
            .accessibilityAddTraits(calendar.view == view ? .isSelected : [])
        }
    }

    private func toolbar(wide: Bool) -> some View {
        HStack(spacing: 10) {
            if wide {
                Button("Sidebar", systemImage: "sidebar.left") { showSidebar.toggle() }.labelStyle(.iconOnly)
                Spacer()
            } else {
                Menu {
                    navigation
                    Button("Settings", systemImage: "gearshape") { calendar.panel = .appearance }
                    Button("Services", systemImage: "square.grid.2x2") { calendar.panel = .services }
                } label: {
                    Image("FRIMark").resizable().frame(width: 33, height: 33).accessibilityLabel("FRI navigation")
                }
                Spacer(minLength: 0)
            }
            Button("Search", systemImage: "magnifyingglass") { calendar.panel = .search }.labelStyle(.iconOnly)
                .accessibilityIdentifier("fri.search")
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
            } label: { Label("Calendar actions", systemImage: "ellipsis.circle").labelStyle(.iconOnly) }
            Menu {
                Button("Schedule", systemImage: "calendar") { calendar.newDraft(deadline: false) }
                Button("One-time deadline", systemImage: "flag") { calendar.newDraft(deadline: true) }
                if !calendar.state.drafts.isEmpty {
                    Button("Resume drafts", systemImage: "doc") { calendar.newDraft(deadline: false) }
                }
            } label: {
                Label("New", systemImage: "plus")
                    .foregroundStyle(colorScheme == .dark ? .black : .white)
            }
                .accessibilityIdentifier("fri.new")
                .buttonStyle(.borderedProminent)
                .tint(colorScheme == .dark ? .white : .black)
        }
        .font(.body)
        .padding(.horizontal, 18).padding(.vertical, 12)
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
                                .accessibilityAddTraits(key == calendar.state.active ? .isSelected : [])
                            if key != CalendarClock.day() {
                                Button("Close date tab", systemImage: "xmark") { calendar.closeTab(key) }
                                    .labelStyle(.iconOnly).buttonStyle(.plain)
                            }
                        }
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(.primary.opacity(key == calendar.state.active ? 0.13 : 0.04), in: Capsule())
                    }
                }
            }.padding(.horizontal, 18)
        }.scrollIndicators(.hidden)
    }

    private var day: some View {
        VStack(alignment: .leading, spacing: 18) {
            ViewThatFits {
                HStack(alignment: .center, spacing: 14) {
                    dayHeading
                    Spacer()
                    dayButtons
                    ring
                }
                VStack(alignment: .leading, spacing: 10) {
                    dayHeading
                    HStack { dayButtons; Spacer(); ring }
                }
            }
            if visible.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "sun.horizon").font(.largeTitle)
                    Text(dayTasks.isEmpty ? "A fresh day." : "Your day is clear.").font(.title2.weight(.semibold))
                    if dayTasks.isEmpty { Button("Add a schedule", systemImage: "plus") { calendar.newDraft(deadline: false) } }
                }
                .padding(24).frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
                .modifier(FRISurface(glass: glass))
            } else {
                FRIMosaic(durations: visible.map(\.duration), largeText: effectiveType.isAccessibilitySize || calendar.state.settings["large"]?.bool == true,
                          list: calendar.state.settings["layout"]?.string == "list") {
                    ForEach(visible) { item in
                        FRICardView(item: item, glass: glass, show: { calendar.appointment = item },
                                    complete: { calendar.setDoneWithoutOpening(item) })
                    }
                }
            }
        }
    }

    private var dayHeading: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(selected, format: .dateTime.month(.wide).day().year())
                .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            Text(selected, format: .dateTime.weekday(.wide))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var dayButtons: some View {
        HStack(spacing: 8) {
            Button("Previous day", systemImage: "chevron.left") { moveDay(-1) }.labelStyle(.iconOnly)
            Button("Today") { calendar.select(CalendarClock.day()) }
            Button("Next day", systemImage: "chevron.right") { moveDay(1) }.labelStyle(.iconOnly)
        }.buttonStyle(.bordered)
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
            if finished { Image(systemName: "checkmark").font(.body.weight(.semibold)) }
            else { Text("\(complete)/\(dayTasks.count)").font(.caption.monospacedDigit()) }
        }
        .frame(width: 50, height: 50)
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
    let show: () -> Void
    let complete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.time).font(.title2.weight(.semibold).monospacedDigit())
                Spacer()
                Button(item.done ? "Mark as pending" : "Done", systemImage: item.done ? "checkmark.circle.fill" : "circle", action: complete)
                    .labelStyle(.iconOnly).buttonStyle(.borderless)
                    .accessibilityIdentifier("fri.done.\(item.id)")
            }
            Button(action: show) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(item.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                    Text(item.isDeadline ? "Deadline" : "\(item.duration) min · \(item.category)")
                        .font(.caption).foregroundStyle(.secondary)
                    if !item.location.isEmpty {
                        Label(item.location, systemImage: "mappin").font(.caption).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(.rect)
            }.buttonStyle(.plain)
            Spacer(minLength: 0)
        }
        .padding(16).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(FRISurface(glass: glass))
        .opacity(item.done ? 0.72 : 1)
    }
}
