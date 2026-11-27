import EventKit
import FRICore
import FRIDesign
import ImageIO
import PDFKit
import SwiftUI
import UniformTypeIdentifiers
import Vision

private enum FRIImportFailure: LocalizedError {
    case unreadable, limit, calendarPermission

    var errorDescription: String? {
        switch self {
        case .unreadable: "FRI could not read this source."
        case .limit: "This source exceeds the import limit."
        case .calendarPermission: "Calendar access was declined. File import is still available."
        }
    }
}

private enum FRIImportReader {
    static func link(_ entered: String) async throws -> SourceRead {
        let source = try await PublicCalendarSource.read(entered)
        return try parse(source, name: "")
    }

    static func parse(_ text: String, name: String) throws -> SourceRead {
        if text.localizedCaseInsensitiveContains("application/ld+json") || ["html", "htm"].contains(URL(fileURLWithPath: name).pathExtension.lowercased()) {
            let result = PlanImport.structuredEvents(text)
            return SourceRead(rows: result.appointments.map(row), warnings: result.notices)
        }
        return try SourcePlanner().read(text, name: name)
    }

    static func row(_ item: Appointment) -> SourceRow {
        ["title": .string(item.title), "kind": .string(item.isDeadline ? "deadline" : "schedule"),
         "date": .string(item.date), "time": .string(item.time), "dueDate": .string(item.date),
         "dueTime": .string(item.time), "duration": .number(Double(item.duration)),
         "location": .string(item.location), "notes": .string(item.notes), "allDay": .bool(item.allDay == true),
         "sourceKey": .string(item.sourceKey ?? "")]
    }

    static func file(_ url: URL) throws -> SourceRead {
        let scope = url.startAccessingSecurityScopedResource()
        defer { if scope { url.stopAccessingSecurityScopedResource() } }
        let kind = url.pathExtension.lowercased()
        let info = try url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
        let document = kind == "pdf"
        let image = info.contentType?.conforms(to: .image) == true
        let limit = kind == "docx" ? 8 * 1024 * 1024 : document ? 12 * 1024 * 1024 : (image ? 4 * 1024 * 1024 : 1_048_576)
        guard (info.fileSize ?? limit + 1) <= limit else { throw FRIImportFailure.limit }
        if document {
            guard let pdf = PDFDocument(url: url), !pdf.isLocked else { throw FRIImportFailure.unreadable }
            let text = try (0..<min(pdf.pageCount, 15)).compactMap { index -> String? in
                guard let page = pdf.page(at: index) else { return nil }
                if let text = page.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return text }
                let pageImage = page.thumbnail(of: CGSize(width: 1_400, height: 1_800), for: .mediaBox)
                #if os(macOS)
                var rect = CGRect(origin: .zero, size: pageImage.size)
                guard let cgImage = pageImage.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return nil }
                #else
                guard let cgImage = pageImage.cgImage else { return nil }
                #endif
                return try recognize(cgImage, orientation: .up)
            }.joined(separator: "\n")
            var result = try SourcePlanner().read(text, name: url.lastPathComponent)
            if pdf.pageCount > 15 { result.warnings.append("Only the first 15 PDF pages were read.") }
            return result
        }
        if image {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 2400
                  ] as CFDictionary) else { throw FRIImportFailure.unreadable }
            return try SourcePlanner().read(recognize(cgImage, orientation: .up), name: url.lastPathComponent)
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: limit + 1) ?? Data()
        guard data.count <= limit else { throw FRIImportFailure.limit }
        if kind == "docx" {
            let planner = try SourcePlanner()
            return try planner.read(planner.documentText(data), name: url.lastPathComponent)
        }
        guard let text = String(data: data, encoding: .utf8) else { throw FRIImportFailure.unreadable }
        return try parse(text, name: url.lastPathComponent)
    }

    private static func recognize(_ image: CGImage, orientation: CGImagePropertyOrientation) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        try VNImageRequestHandler(cgImage: image, orientation: orientation).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}

struct FRIImportView: View {
    let calendar: FRICalendarSession
    @State private var text = ""
    @State private var link = ""
    @State private var pickFiles = false
    @State private var pickFolder = false
    @State private var feedback = ""
    @State private var selectedRow: String?
    @State private var website: SourceWebsite?
    @State private var apiKey = ""
    @State private var pickAIImage = false
    @State private var websiteLink: String?
    @State private var eventStore = EKEventStore()

    private var selected: PreparedSource? {
        calendar.state.importQueue.first { $0.id == calendar.selectedSource }
    }
    private var archived: SavedSource? {
        calendar.state.sourceLibrary.first { $0.id == calendar.selectedSource }
    }
    private let fileTypes: [UTType] = [.calendarEvent, .commaSeparatedText, .plainText, .pdf, .image, .json, .html,
                                       UTType(filenameExtension: "docx") ?? .data]

    var body: some View {
        FRISheetView(title: "Sources") {
            Form {
                if let selected {
                    Section(selected.label) {
                        if let warnings = selected.warnings {
                            ForEach(Array(warnings.enumerated()), id: \.offset) { Text($0.element).foregroundStyle(.secondary) }
                        }
                        ForEach(selected.rows, id: \.sourceKey) { row in
                            Button {
                                selectedRow = row.sourceKey
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(row["title"]?.string ?? "Untitled plan")
                                    Text(row.holdReason ?? (row["date"]?.string).nonempty ?? (row["dueDate"]?.string).nonempty ?? "Review details")
                                        .friFont(.caption).foregroundStyle(FRIColors.muted)
                                }
                            }
                            if selectedRow == row.sourceKey {
                                SourceQuestion(row: row) { updated in
                                    let ok = calendar.change { state in
                                        guard let batch = state.importQueue.firstIndex(where: { $0.id == selected.id }),
                                              let index = state.importQueue[batch].rows.firstIndex(of: row) else {
                                            throw SourceFailure("This source changed. Reopen its current row.")
                                        }
                                        state.importQueue[batch].rows[index] = updated
                                        for field in ["repeatFrom", "repeatUntil"] where row[field] != updated[field] {
                                            for i in state.importQueue[batch].rows.indices {
                                                if case .array(let days) = state.importQueue[batch].rows[i]["weekdays"], !days.isEmpty,
                                                   (state.importQueue[batch].rows[i][field]?.string).nonempty == nil {
                                                    state.importQueue[batch].rows[i][field] = updated[field]
                                                }
                                            }
                                        }
                                    }
                                    if ok { selectedRow = updated.sourceKey }
                                    return ok
                                }.id(row)
                                Button("Skip this plan") {
                                    _ = calendar.change { state in
                                        guard let i = state.importQueue.firstIndex(where: { $0.id == selected.id }) else { return }
                                        state.importQueue[i].rows.removeAll { $0 == row }
                                        if state.importQueue[i].rows.isEmpty { state.importQueue.remove(at: i) }
                                    }
                                }
                            }
                        }
                    }
                    SourceWorkingHours(source: selected) { start, end in
                        calendar.change { state in
                            guard let index = state.importQueue.firstIndex(where: { $0.id == selected.id }) else {
                                throw SourceFailure("Source already refreshed.")
                            }
                            var settings = state.importQueue[index].settings ?? [:]
                            settings["workStart"] = .number(Double(start))
                            settings["workEnd"] = .number(Double(end))
                            state.importQueue[index].settings = settings
                        }
                    }.id(selected.id)
                    Button("Add ready plans") { refresh() }.accessibilityIdentifier("fri.import.refresh")
                    Button("All sources") { calendar.selectedSource = nil; selectedRow = nil }
                    Button("Remove source", role: .destructive) { removeSource(selected.id) }
                } else if let archived {
                    Section(archived.label) {
                        Text("Source saved")
                        Button("Read again") { link = archived.links?.first ?? ""; calendar.selectedSource = nil }
                        Button("All sources") { calendar.selectedSource = nil }
                        Button("Remove source", role: .destructive) { removeSource(archived.id) }
                    }
                } else {
                    Section("Add a source") {
                        #if os(macOS)
                        TextEditor(text: $text)
                            .frame(minHeight: 72)
                            .accessibilityLabel("Paste plans").accessibilityIdentifier("fri.import.text")
                        #else
                        TextField("Paste plans", text: $text, axis: .vertical).accessibilityIdentifier("fri.import.text")
                        #endif
                        Button("Read text") {
                            let input = String(text.prefix(60_000))
                            read(label: websiteLink.flatMap { URL(string: $0)?.host } ?? "Pasted text", links: websiteLink.map { [$0] } ?? []) { try FRIImportReader.parse(input, name: "") }
                        }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("fri.import.reviewText")
                        Button("Choose files or images…") { pickFiles = true }
                            .fileImporter(isPresented: $pickFiles, allowedContentTypes: fileTypes, allowsMultipleSelection: true) { result in
                                guard case .success(let urls) = result else { return }
                                readFiles(urls, folder: false)
                            }
                        Button("Choose a folder…") { pickFolder = true }
                            .fileImporter(isPresented: $pickFolder, allowedContentTypes: [.folder]) { result in
                                guard case .success(let url) = result else { return }
                                readFiles([url], folder: true)
                            }
                        TextField("Public HTTPS calendar link", text: $link).accessibilityIdentifier("fri.import.link")
                        Button("Read link") {
                            let value = link.trimmingCharacters(in: .whitespacesAndNewlines)
                            read(label: URL(string: value)?.host ?? "Calendar link", links: [value]) { try await FRIImportReader.link(value) }
                        }.disabled(link.isEmpty).accessibilityIdentifier("fri.import.readLink")
                        Button("Open website to sign in…") {
                            do {
                                guard let url = URL(string: link) else { throw FRIImportFailure.unreadable }
                                website = try SourceWebsite(url)
                            } catch { feedback = error.localizedDescription }
                        }.disabled(link.isEmpty)
                        Button("Connect Apple Calendar") { connectCalendar() }.accessibilityIdentifier("fri.import.connectCalendar")
                    }
                    DisclosureGroup("Optional OpenAI extraction") {
                        Text("Use this for a complex timetable after reviewing the local result. Sending uses your OpenAI account and may incur charges.")
                            .friFont(.caption)
                        SecureField("OpenAI API key", text: $apiKey)
                        HStack {
                            Button("Save key on this device") { setKey(apiKey) }.disabled(apiKey.isEmpty)
                            Button("Remove key") { setKey("") }
                        }
                        Button("Send pasted text to OpenAI") {
                            let input = text
                            assist(text: input, label: websiteLink.flatMap { URL(string: $0)?.host } ?? "Pasted text")
                        }.disabled(text.isEmpty || calendar.readingSource)
                        Button("Choose image to send to OpenAI…") { pickAIImage = true }
                            .fileImporter(isPresented: $pickAIImage, allowedContentTypes: [.png, .jpeg, .webP]) { result in
                                guard case .success(let url) = result else { return }
                                do {
                                    let scoped = url.startAccessingSecurityScopedResource()
                                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                                    let info = try url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
                                    guard let size = info.fileSize, size <= 8 * 1024 * 1024,
                                          let mime = info.contentType?.preferredMIMEType else { throw FRIImportFailure.limit }
                                    assist(text: "", label: url.lastPathComponent, image: try Data(contentsOf: url), mime: mime)
                                } catch { feedback = error.localizedDescription }
                            }
                    }
                    if !calendar.state.sourceLibrary.isEmpty || !calendar.state.importQueue.isEmpty {
                        Section("Your sources") {
                            ForEach(calendar.state.importQueue) { batch in
                                Button("\(batch.label) · \(batch.rows.count) prepared") { choose(batch) }
                            }
                            ForEach(calendar.state.sourceLibrary.filter { item in !calendar.state.importQueue.contains { $0.id == item.id } }) { source in
                                Button(source.label) { calendar.selectedSource = source.id }
                            }
                        }
                    }
                    Button("Add ready plans") { refresh() }.disabled(calendar.state.importQueue.isEmpty)
                }
                if calendar.readingSource {
                    ProgressView("Reading source…")
                    Button("Cancel reading") { calendar.cancelSourceRead() }
                }
                if !feedback.isEmpty { Text(feedback).accessibilityIdentifier("fri.import.feedback.message") }
                if let message = calendar.message { Text(message).accessibilityIdentifier("fri.source.status") }
            }.formStyle(.grouped).accessibilityIdentifier("fri.import.form")
            .sheet(item: $website) { source in
                FRISourceWebsiteView(source: source) { visible in
                    text = visible
                    websiteLink = source.url.absoluteString
                    feedback = "Review the visible text, then choose Read text."
                }
            }
            .onChange(of: calendar.selectedSource, initial: true) {
                if let selected { choose(selected) }
            }
        }
        .onDisappear { calendar.selectedSource = nil }
    }

    private func setKey(_ value: String) {
        do {
            try AssistedSourceRead.storeKey(value)
            apiKey = ""
            feedback = value.isEmpty ? "Key removed." : "Key saved in Keychain."
        } catch { feedback = error.localizedDescription }
    }

    private func assist(text: String, label: String, image: Data? = nil, mime: String = "image/jpeg") {
        let cacheKey = AssistedSourceRead.cacheKey(text: text, image: image)
        calendar.readSource(label: label, links: image == nil ? websiteLink.map { [$0] } ?? [] : [], cacheKey: cacheKey) {
            try await AssistedSourceRead.extract(text: text, image: image, mime: mime)
        }
    }

    private func choose(_ batch: PreparedSource) {
        calendar.selectedSource = batch.id
        let planner = try? SourcePlanner()
        selectedRow = batch.rows.first { (try? planner?.question($0)) != nil || $0.holdReason != nil }?.sourceKey
    }

    private func removeSource(_ id: String) {
        if calendar.change({ state in
            state.importQueue.removeAll { $0.id == id }
            state.sourceLibrary.removeAll { $0.id == id }
        }) { calendar.selectedSource = nil }
    }

    private func refresh() {
        calendar.refreshSources()
        if let selected { choose(selected) }
    }

    private func read(label: String, links: [String] = [], work: @escaping @Sendable () async throws -> SourceRead) {
        feedback = ""
        calendar.readSource(label: label, links: links, work: work)
    }

    private func readFiles(_ urls: [URL], folder: Bool) {
        guard let first = urls.first else { return }
        read(label: urls.count == 1 ? first.lastPathComponent : "\(first.lastPathComponent) + \(urls.count - 1)") {
            let scoped = folder && first.startAccessingSecurityScopedResource()
            defer { if scoped { first.stopAccessingSecurityScopedResource() } }
            let files: [URL]
            if folder {
                let allowed = Set(["ics","csv","json","txt","html","htm","pdf","docx","png","jpg","jpeg","heic","webp"])
                let contents = try FileManager.default.contentsOfDirectory(at: first, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey], options: .skipsHiddenFiles)
                files = try contents.filter {
                    let info = try $0.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                    return info.isRegularFile == true && info.isSymbolicLink != true && allowed.contains($0.pathExtension.lowercased())
                }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            } else { files = urls }
            var result = SourceRead()
            for url in files.prefix(50) {
                try Task.checkCancellation()
                do {
                    let part = try FRIImportReader.file(url)
                    result.rows += part.rows
                    result.warnings += part.warnings
                } catch { result.warnings.append("\(url.lastPathComponent): \(error.localizedDescription)") }
                if result.rows.count >= 500 { break }
            }
            if files.count > 50 { result.warnings.append("Only the first 50 files were read.") }
            return result
        }
    }

    private func connectCalendar() {
        Task {
            do {
                guard try await eventStore.requestFullAccessToEvents() else { throw FRIImportFailure.calendarPermission }
                let clock = CalendarClock.local, start = CalendarClock.local.startOfDay(for: .now)
                guard let end = clock.date(byAdding: .day, value: 7, to: start) else { throw CalendarError.invalidDate }
                let events = eventStore.events(matching: eventStore.predicateForEvents(withStart: start, end: end, calendars: nil))
                let rows: [SourceRow] = events.prefix(500).map { event in
                    var item = Appointment()
                    item.title = String((event.title ?? "").prefix(160))
                    item.date = CalendarClock.day(event.startDate)
                    item.location = String((event.location ?? "").prefix(200))
                    item.notes = "Apple Calendar · " + String(event.calendar.title.prefix(120))
                    item.sourceKey = "eventkit:\(event.calendarItemIdentifier):\(event.startDate.timeIntervalSince1970)"
                    item.time = CalendarClock.time(clock.component(.hour, from: event.startDate) * 60 + clock.component(.minute, from: event.startDate))
                    item.duration = min(1440, max(0, Int(event.endDate.timeIntervalSince(event.startDate) / 60)))
                    item.allDay = event.isAllDay
                    return FRIImportReader.row(item)
                }
                read(label: "Apple Calendar") { SourceRead(rows: rows) }
            } catch { feedback = error.localizedDescription }
        }
    }
}

private extension Optional where Wrapped == String {
    var nonempty: String? { flatMap { $0.isEmpty ? nil : $0 } }
}

private extension Dictionary where Key == String, Value == JSONValue {
    var sourceKey: String { self["sourceKey"]?.string ?? "" }
    var holdReason: String? {
        if case .array(let reasons) = self["holdReasons"] { return reasons.compactMap(\.string).first }
        return nil
    }
}

private struct SourceQuestion: View {
    let row: SourceRow
    let save: (SourceRow) -> Bool
    @State private var field = ""
    @State private var answer = ""
    @State private var question: [String]?
    @State private var error = ""

    private var fields: [String] {
        let kind = row["kind"]?.string
        if kind == "task" { return ["title", "dueDate", "dueTime", "effortMinutes", "leadDays"] }
        if kind == "deadline" { return ["title", "dueDate", "dueTime"] }
        if case .array(let days) = row["weekdays"], !days.isEmpty { return ["title","repeatFrom","repeatUntil","time","duration"] }
        return ["title", "date", "time", "duration"]
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let question { Text(question[1]).friFont(.headline) }
            else {
                Picker("Edit detail", selection: $field) { ForEach(fields, id: \.self) { Text($0).tag($0) } }
            }
            if field == "kind" {
                Picker("Plan type", selection: $answer) {
                    Text("Fixed appointment").tag("schedule")
                    Text("Work before deadline").tag("task")
                    Text("Deadline only").tag("deadline")
                }
            } else {
                TextField(field, text: $answer).accessibilityIdentifier("fri.source.answer")
            }
            Button(question == nil ? "Save detail" : "Continue") { submit() }.accessibilityIdentifier("fri.source.save")
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
        }.onAppear {
            question = try? SourcePlanner().question(row)
            field = question?.first ?? (row.holdReason == nil ? "title" : (fields.contains("time") ? "time" : fields[0]))
            populate()
        }.onChange(of: field) { populate() }
    }

    private func populate() {
        if case .number(let n) = row[field] { answer = n == 0 ? "" : String(Int(n)) }
        else { answer = field == "kind" ? "schedule" : row[field]?.string ?? "" }
    }

    private func submit() {
        do {
            let planner = try SourcePlanner()
            var next = row
            if ["duration","effortMinutes","leadDays","periodMinutes"].contains(field) {
                guard let number = Int(answer), number > 0, number <= 525600 else { throw SourceFailure("Enter a positive whole number.") }
                next[field] = .number(Double(number))
                if field == "periodMinutes", case .number(let periods) = row["periods"] { next["duration"] = .number(periods * Double(number)) }
            } else { next[field] = .string(answer) }
            next = try planner.normalized(next)
            guard next[field] != .string(""), next[field] != .number(0),
                  !(field == "repeatUntil" && (next[field]?.string ?? "") < (next["repeatFrom"]?.string ?? "")) else {
                throw SourceFailure("Enter a valid value.")
            }
            _ = save(next)
        } catch { self.error = error.localizedDescription }
    }
}

private struct SourceWorkingHours: View {
    let source: PreparedSource
    let save: (Int, Int) -> Bool
    @State private var start = "09:00"
    @State private var end = "18:00"
    @State private var feedback = ""
    var body: some View {
        DisclosureGroup("Work hours for assignments") {
            TextField("Start (HH:mm)", text: $start)
            TextField("End (HH:mm)", text: $end)
            Button("Save hours") {
                guard let first = CalendarClock.minutes(start), let last = CalendarClock.minutes(end), first < last else {
                    feedback = "Choose a valid start and end on the same day."; return
                }
                if save(first, last) { feedback = "Work hours saved." }
            }
            if !feedback.isEmpty { Text(feedback).font(.caption) }
        }.onAppear {
            if case .number(let n) = source.settings?["workStart"], (0..<1440).contains(n) { start = CalendarClock.time(Int(n)) }
            if case .number(let n) = source.settings?["workEnd"], (1...1440).contains(n) { end = CalendarClock.time(Int(n)) }
        }
    }
}
