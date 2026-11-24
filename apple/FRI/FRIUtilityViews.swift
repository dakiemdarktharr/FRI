import FRICore
import FRIDesign
import ImageIO
import SwiftUI
import WidgetKit
import UniformTypeIdentifiers

struct FRICollectionsView: View {
    let calendar: FRICalendarSession
    @State private var name = ""
    @State private var error: String?

    var body: some View {
        FRISheetView(title: "A new collection") {
            Form {
                TextField("Collection name", text: $name)
                    .accessibilityIdentifier("fri.collection.name")
                Text("Use this name in an appointment’s Category field to include it in the collection.")
                    .friFont(.caption).foregroundStyle(.secondary)
                if let error { Text(error).foregroundStyle(.red) }
                Button("Create collection") {
                    let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !value.isEmpty, value.utf16.count <= 35 else {
                        error = "Enter a collection name of up to 35 characters."
                        return
                    }
                    if calendar.change({ state in
                        if !state.collections.contains(.string(value)) { state.collections.append(.string(value)) }
                    }) { calendar.panel = nil }
                    else { error = calendar.message }
                }.buttonStyle(.borderedProminent).tint(FRIColors.marsala).foregroundStyle(FRIColors.cream)
            }.formStyle(.grouped)
        }
    }
}

struct FRISearchView: View {
    let tasks: [Appointment]
    let select: (Appointment) -> Void
    @State private var query = ""

    private var results: [Appointment] {
        tasks.filter(matches).sorted { ($0.date, $0.time, $0.id) < ($1.date, $1.time, $1.id) }
    }

    var body: some View {
        FRISheetView(title: "Search") {
            VStack {
                TextField("Search appointments", text: $query)
                    .textFieldStyle(FRISheetTextFieldStyle()).padding()
                    .accessibilityIdentifier("fri.search.field")
                    .submitLabel(.search)
                    .onSubmit { if let first = results.first { select(first) } }
                if results.isEmpty {
                    ContentUnavailableView {
                        Label("No appointments found", systemImage: "magnifyingglass")
                    } description: {
                        Text(tasks.isEmpty ? "Add an appointment to find it here." : "Try another word.")
                    }
                    .accessibilityIdentifier("fri.search.empty")
                } else {
                    List {
                        ForEach(results) { task in
                            Button { select(task) } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(task.title)
                                    Text("\(task.date) · \(task.time)").friFont(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("fri.search.result.\(task.id)")
                        }
                    }
                }
            }
        }
    }

    private func matches(_ item: Appointment) -> Bool {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return term.isEmpty || [item.title, item.category, item.location, item.notes].contains { $0.localizedStandardContains(term) }
    }
}

struct FRIManageView: View {
    let tasks: [Appointment]
    let remove: (Set<String>) -> Void
    @State private var selections: Set<String> = []
    @State private var confirming = false

    var body: some View {
        FRISheetView(title: "Manage appointments") {
            Form {
                ForEach(tasks) { task in
                    Toggle(isOn: Binding(get: { selections.contains(task.id) }, set: { selected in
                        if selected { selections.insert(task.id) } else { selections.remove(task.id) }
                    })) {
                        Text(task.title)
                        Text(task.time).friFont(.caption).foregroundStyle(.secondary)
                    }
                    .accessibilityLabel(task.title)
                    .accessibilityHint(task.time)
                    .accessibilityIdentifier("fri.manage.select.\(task.id)")
                }
                Button("Delete selected (\(selections.count))", role: .destructive) { confirming = true }
                    .disabled(selections.isEmpty)
                    .accessibilityIdentifier("fri.manage.delete")
            }
            .formStyle(.grouped)
            .confirmationDialog("Delete these appointments?", isPresented: $confirming) {
                Button("Delete", role: .destructive) { remove(selections) }
            }
        }
    }
}

struct FRIPlannerView: View {
    let calendar: FRICalendarSession
    @State private var title = ""
    @State private var date = Date.now
    @State private var duration = 60
    @State private var deadline = "18:00"
    @State private var result: String?

    var body: some View {
        FRISheetView(title: "Find time for a task") {
            Form {
                TextField("Task name", text: $title).accessibilityIdentifier("fri.planner.title")
                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .accessibilityIdentifier("fri.planner.date")
                VStack(alignment: .leading, spacing: 6) {
                    Text("Minutes needed").friFont(.caption)
                    TextField("Minutes needed", value: $duration, format: .number)
                        .accessibilityIdentifier("fri.planner.duration")
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Finish before (HH:mm)").friFont(.caption)
                    TextField("Finish before (HH:mm)", text: $deadline)
                        .accessibilityIdentifier("fri.planner.deadline")
                }
                Text("Find an uninterrupted window after 09:00 around the appointments on this date.")
                    .friFont(.caption).foregroundStyle(.secondary)
                Button("Find a time") { plan() }.accessibilityIdentifier("fri.planner.find")
                if let result { Text(result).accessibilityIdentifier("fri.planner.result") }
            }.formStyle(.grouped).accessibilityIdentifier("fri.planner.form")
        }.onAppear { date = CalendarClock.date(calendar.state.active) ?? .now }
    }

    private func plan() {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, (1...720).contains(duration), let end = CalendarClock.minutes(deadline), end > 540 else {
            result = "Enter a task name, 1–720 minutes and an end time after 09:00."
            return
        }
        let active = CalendarClock.day(date)
        let slots = Planning.free(in: calendar.state.tasks, day: active, end: end)
        guard let slot = slots.first(where: { $0.count >= duration }) else {
            let total = slots.reduce(0) { $0 + $1.count }
            result = total < duration ? "You need \(duration - total) more free minutes." :
                "You have \(total) free minutes, with no uninterrupted \(duration)-minute slot."
            return
        }
        var draft = Appointment()
        draft.title = String(name.prefix(160))
        draft.date = active
        draft.time = CalendarClock.time(slot.lowerBound)
        draft.duration = duration
        draft.kind = "schedule"
        draft.category = "Work"
        draft.notes = "Placed in an open window before \(deadline)"
        if calendar.addDrafts([draft]) { calendar.reviewDrafts([draft.id]) }
        else { result = calendar.message }
    }
}

struct FRIAvailabilityView: View {
    let action: (FRICalendarSession.FileAction) -> Void

    var body: some View {
        FRISheetView(title: "Find time together") {
            Form {
                Text("Share only free intervals from 09:00 to 18:00 over the next seven days. Appointment names, locations and notes stay on this device.")
                Button("Export my free time") { action(.exportAvailability) }
                Button("Compare a free-time file") { action(.compareAvailability) }
            }.formStyle(.grouped)
        }
    }
}

struct FRIWidgetHelpView: View {
    let calendar: FRICalendarSession
    @State private var size = 0
    @State private var useExample = true
    @State private var largeText = false

    private var family: WidgetFamily {
        switch size {
        case 1: .systemMedium
        case 2: .systemLarge
        default: .systemSmall
        }
    }

    var body: some View {
        FRISheetView(title: "Add FRI Widget") {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("In your calendar").friFont(.title2, weight: .bold)
                    Text("Choose the cards beside your appointments.").foregroundStyle(.secondary)
                    ForEach([("upnext", "Up next"), ("weather", "Weather"), ("maps", "Maps"), ("spotify", "Spotify"), ("health", "Manual activity")], id: \.0) { key, label in
                        Toggle(label, isOn: Binding(get: { calendar.state.widgets.contains(.string(key)) }, set: { enabled in
                            _ = calendar.change { state in
                                state.widgets.removeAll { $0 == .string(key) }
                                if enabled { state.widgets.append(.string(key)) }
                            }
                        }))
                        .accessibilityIdentifier("fri.widget.card.\(key)")
                    }
                    Divider()
                    #if os(macOS)
                    Text("Desktop widgets").friFont(.title2, weight: .bold)
                    Text("Add a Swift desktop widget, drag its top bar to move it, and drag the bottom-right corner to resize. Your position and size are restored when FRI reopens.")
                    Button("Create desktop widget", systemImage: "plus") { calendar.addDesktopWidget() }
                        .buttonStyle(.borderedProminent).tint(FRIColors.marsala).foregroundStyle(FRIColors.cream)
                    Button("Show desktop widgets") { calendar.showDesktopWidgets() }
                    Text("Desktop widgets use this app’s calendar. FRI must be running. The system WidgetKit gallery uses a separately configured shared store.")
                        .friFont(.caption).foregroundStyle(.secondary)
                    Divider()
                    #endif
                    Text("Auto fit").friFont(.title2, weight: .bold)
                    Text("Your widget adapts to its size. The next appointment and Done stay first; more details appear when there is room.")
                        .foregroundStyle(.secondary)
                    Picker("Widget size", selection: $size) {
                        Text("Small").tag(0)
                        Text("Medium").tag(1)
                        Text("Large").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("fri.widget.size")
                    Toggle("Example appointments", isOn: $useExample)
                    Toggle("Preview large text", isOn: $largeText)
                    GeometryReader { geometry in
                        let width = min(geometry.size.width, size == 0 ? 160 : 340)
                        FRIWidgetContent(
                            snapshot: WidgetSnapshot(state: useExample ? .widgetSample : calendar.state,
                                                     day: .now, now: .now),
                            family: family
                        ) {
                            Image(systemName: "checkmark.circle.fill").friFont(.title2)
                                .accessibilityLabel("Complete appointment preview")
                        }
                        .environment(\.dynamicTypeSize, largeText ? .accessibility1 : .large)
                        .padding(16)
                        .frame(width: width, height: size == 2 ? 340 : 160)
                        .background(.background, in: RoundedRectangle(cornerRadius: 24))
                        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.secondary.opacity(0.25)))
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("fri.widget.preview")
                    }
                    .frame(height: size == 2 ? 340 : 160)
                    Text("Size preview · add the actual widget from the system gallery. Preview controls do not change your appointments.")
                        .friFont(.caption).foregroundStyle(.secondary)
                    Divider()
                    #if os(macOS)
                    Text("Add to your desktop").friFont(.headline)
                    Text("Control-click the desktop → Edit Widgets → FRI → choose a size. Drag the widget from the gallery onto your desktop.")
                    Text("Move or resize").friFont(.headline)
                    Text("Drag a desktop widget to move it. Control-click it to choose Small, Medium or Large, edit its date, or remove it.")
                    #else
                    Text("Add to your Home Screen").friFont(.headline)
                    Text("Touch and hold the Home Screen → Edit → Add Widget → FRI. On iOS 17, tap + instead of Edit. Choose a size and tap Add Widget.")
                    Text("Move or resize").friFont(.headline)
                    Text("Touch and hold the widget, choose Edit Home Screen, then drag it to a new position. On iOS 18 or later, use the size choices in its menu. On iOS 17, remove it and add the size you want.")
                    #endif
                    Text("Tap the checkmark to finish an appointment. Tap elsewhere to open its day. Removing a widget keeps your appointments.")
                }
                .padding(20)
            }
            .accessibilityIdentifier("fri.widget.gallery")
        }
    }
}

struct FRIAppearanceView: View {
    let calendar: FRICalendarSession
    @State private var pickImage = false
    @State private var error: String?

    var body: some View {
        FRISheetView(title: "Settings") {
            Form {
                Text("A space that feels like you")
                    .friFont(.title2, weight: .semibold)
                    .fixedSize(horizontal: false, vertical: true)
                    .listRowBackground(Color.clear)
                Section("Appearance") {
                    Picker("Sidebar background", selection: setting("sidebar", initial: "gradient")) {
                        Text("Moving gradient").tag("gradient")
                        Text("Solid charcoal").tag("solid")
                        if calendar.state.sidebarImageData != nil { Text("My image").tag("image") }
                    }.accessibilityIdentifier("fri.settings.sidebar")
                    Text("Soft movement, a still color, or your own image.")
                        .friFont(.caption).foregroundStyle(.secondary)
                    Button("Choose sidebar photo…") { pickImage = true }
                    Text("Photos you choose here are saved as a resized, still JPEG preview without the original file metadata.")
                        .friFont(.caption).foregroundStyle(.secondary)
                    if calendar.state.sidebarImageData != nil {
                        Button("Remove sidebar photo", role: .destructive) {
                            _ = calendar.change {
                                $0.settings["appleSidebarImage"] = nil
                                $0.settings["image"] = nil
                                $0.settings["sidebar"] = .string("gradient")
                            }
                        }
                    }
                    LabeledContent("Palette") {
                        HStack(spacing: 8) {
                            ForEach([FRIColors.cream, FRIColors.ink, FRIColors.marsala], id: \.self) { color in
                                Circle().fill(color).overlay(Circle().strokeBorder(FRIColors.line)).frame(width: 22, height: 22)
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Ivory, charcoal and Fri marsala")
                    }
                }
                Section("Reminders") {
                    Toggle("Appointment reminders", isOn: Binding(get: { calendar.state.settings["reminders"]?.bool == true }, set: { value in
                        Task { await calendar.setReminders(value) }
                    })).tint(FRIColors.marsala)
                    Text("A private reminder arrives five minutes before each appointment. Notifications hide appointment details.")
                        .friFont(.caption).foregroundStyle(.secondary)
                }
                Section("Comfort") {
                    Toggle(isOn: toggle("glass", initial: true)) {
                        Text("Liquid glass")
                        Text("Turn off for solid, quieter surfaces.").friFont(.caption).foregroundStyle(.secondary)
                    }.tint(FRIColors.marsala).accessibilityLabel("Liquid glass")
                    Toggle(isOn: toggle("motion", initial: true)) {
                        Text("Gentle motion")
                        Text("Includes the moving sidebar. Respects Reduce Motion.").friFont(.caption).foregroundStyle(.secondary)
                    }.tint(FRIColors.marsala).accessibilityLabel("Gentle motion")
                    Toggle(isOn: toggle("large", initial: false)) {
                        Text("Larger text")
                        Text("A little more room to read.").friFont(.caption).foregroundStyle(.secondary)
                    }.tint(FRIColors.marsala).accessibilityLabel("Larger text")
                        .accessibilityIdentifier("fri.settings.largeText")
                    Picker("Layout", selection: setting("layout", initial: "mosaic")) {
                        Text("Duration mosaic").tag("mosaic")
                        Text("List").tag("list")
                    }.accessibilityIdentifier("fri.settings.layout")
                }
                Button("Restore look") {
                    _ = calendar.change {
                        $0.settings["glass"] = .bool(true)
                        $0.settings["motion"] = .bool(true)
                        $0.settings["large"] = .bool(false)
                        $0.settings["sidebar"] = .string("gradient")
                        $0.settings["layout"] = .string("mosaic")
                    }
                }
                if let error { Text(error).foregroundStyle(.red) }
                if let message = calendar.message { Text(message).foregroundStyle(.red) }
            }
            .formStyle(.grouped)
            .accessibilityIdentifier("fri.settings.form")
            .fileImporter(isPresented: $pickImage, allowedContentTypes: [.image]) { result in
                Task {
                    do {
                        let url = try result.get()
                        let encoded = try await Task.detached { try FRIAppearanceView.thumbnail(at: url) }.value
                        _ = calendar.change {
                            $0.settings["image"] = .string("data:image/jpeg;base64," + encoded)
                            $0.settings["appleSidebarImage"] = nil
                            $0.settings["sidebar"] = .string("image")
                        }
                        error = nil
                    } catch { self.error = error.localizedDescription }
                }
            }
        }
    }

    private func toggle(_ key: String, initial: Bool) -> Binding<Bool> {
        Binding(get: { calendar.state.settings[key]?.bool ?? initial }, set: { calendar.updateSetting(key, .bool($0)) })
    }

    private func setting(_ key: String, initial: String) -> Binding<String> {
        Binding(get: { calendar.state.settings[key]?.string ?? initial }, set: { calendar.updateSetting(key, .string($0)) })
    }

    private nonisolated static func thumbnail(at url: URL) throws -> String {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let info = try url.resourceValues(forKeys: [.fileSizeKey])
        guard (info.fileSize ?? 0) <= 20 * 1024 * 1024,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 720
              ] as CFDictionary) else { throw CocoaError(.fileReadCorruptFile) }
        let bytes = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(bytes, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.7] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        return (bytes as Data).base64EncodedString()
    }
}
