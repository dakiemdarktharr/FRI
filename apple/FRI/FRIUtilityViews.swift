import FRICore
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

struct FRISearchView: View {
    let tasks: [Appointment]
    let select: (Appointment) -> Void
    @State private var query = ""

    var body: some View {
        FRISheetView(title: "Search") {
            VStack {
                TextField("Search appointments", text: $query)
                    .textFieldStyle(.roundedBorder).padding()
                    .accessibilityIdentifier("fri.search.field")
                List {
                    ForEach(tasks.filter(matches).sorted { ($0.date, $0.time) < ($1.date, $1.time) }) { task in
                        Button { select(task) } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(task.title)
                                Text("\(task.date) · \(task.time)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("fri.search.result.\(task.id)")
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
                        Text(task.time).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Button("Delete selected (\(selections.count))", role: .destructive) { confirming = true }
                    .disabled(selections.isEmpty)
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
    @State private var duration = 60
    @State private var deadline = "18:00"
    @State private var result: String?

    var body: some View {
        FRISheetView(title: "Find time for a task") {
            Form {
                TextField("Task name", text: $title)
                TextField("Minutes needed", value: $duration, format: .number)
                TextField("Finish before (HH:mm)", text: $deadline)
                Button("Find a time") { plan() }
                if let result { Text(result) }
            }.formStyle(.grouped)
        }
    }

    private func plan() {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, (1...720).contains(duration), let end = CalendarClock.minutes(deadline), end > 540 else {
            result = "Enter a task name, 1–720 minutes and an end time after 09:00."
            return
        }
        let active = calendar.state.active
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
        if calendar.addDrafts([draft]) { calendar.newDraft(deadline: false) }
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
    var body: some View {
        FRISheetView(title: "Add FRI Widget") {
            Form {
                #if os(macOS)
                Text("Control-click the desktop, choose Edit Widgets, then search for FRI and pick a size.")
                #else
                Text("Touch and hold the Home Screen, tap Edit, then Add Widget. Search for FRI and choose a size.")
                #endif
                Text("Tap the checkmark to finish the current appointment. Tap elsewhere on the widget to open its day in FRI.")
                if ProcessInfo.processInfo.environment["FRI_SYNTHETIC_PREVIEW"] == "1" {
                    Text("Development sample data is private to this preview.")
                }
            }.formStyle(.grouped)
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
                Section("Appearance") {
                    Toggle("Translucent surfaces", isOn: toggle("glass", initial: true))
                    Toggle("Large text", isOn: toggle("large", initial: false))
                    Toggle("Sidebar movement", isOn: toggle("motion", initial: true))
                    Picker("Layout", selection: setting("layout", initial: "mosaic")) {
                        Text("Duration mosaic").tag("mosaic")
                        Text("List").tag("list")
                    }
                    Picker("Sidebar", selection: setting("sidebar", initial: "gradient")) {
                        Text("Gradient").tag("gradient")
                        Text("Solid").tag("solid")
                        if calendar.state.settings["appleSidebarImage"] != nil { Text("Photo").tag("image") }
                    }
                    Button("Choose sidebar photo…") { pickImage = true }
                    if calendar.state.settings["appleSidebarImage"] != nil {
                        Button("Remove sidebar photo", role: .destructive) {
                            _ = calendar.change {
                                $0.settings["appleSidebarImage"] = nil
                                $0.settings["sidebar"] = .string("gradient")
                            }
                        }
                    }
                }
                Section("Reminders") {
                    Toggle("Appointment reminders", isOn: Binding(get: { calendar.state.settings["reminders"]?.bool == true }, set: { value in
                        Task { await calendar.setReminders(value) }
                    }))
                    Text("Notifications use a generic title and hide appointment details.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let error { Text(error).foregroundStyle(.red) }
                if let message = calendar.message { Text(message).foregroundStyle(.red) }
            }
            .formStyle(.grouped)
            .fileImporter(isPresented: $pickImage, allowedContentTypes: [.image]) { result in
                Task {
                    do {
                        let url = try result.get()
                        let encoded = try await Task.detached { try FRIAppearanceView.thumbnail(at: url) }.value
                        _ = calendar.change {
                            $0.settings["appleSidebarImage"] = .string(encoded)
                            $0.settings["sidebar"] = .string("image")
                        }
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
