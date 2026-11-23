import EventKit
import FRICore
import FRIDesign
import ImageIO
import PDFKit
import SwiftUI
import UniformTypeIdentifiers
import Vision

struct FRIImportView: View {
    let calendar: FRICalendarSession
    @State private var text = ""
    @State private var link = ""
    @State private var notices: [String] = []
    @State private var items: [Appointment] = []
    @State private var acceptedIDs: Set<String> = []
    @State private var pickFile = false
    @State private var busy = false
    @State private var eventStore = EKEventStore()
    @State private var operation: Task<Void, Never>?
    @State private var showFeedback = false

    var body: some View {
        FRISheetView(title: "Import plans") {
            Form {
                if items.isEmpty {
                    Section("Paste plans") {
                        TextField("One appointment per line", text: $text, axis: .vertical)
                            .accessibilityIdentifier("fri.import.text")
                        Button("Review text") {
                            append(PlanImport.text(String(text.prefix(20_000))))
                        }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("fri.import.reviewText")
                    }
                    Section("Calendar files and images") {
                        Button("Choose ICS, CSV, text, PDF or image…") { pickFile = true }
                        Text("CSV uses a title column with optional date, time, duration, kind, location and notes. FRI reads images locally.")
                            .friFont(.caption).foregroundStyle(.secondary)
                    }
                    Section("Calendar link") {
                        TextField("Public HTTPS calendar link", text: $link)
                            .accessibilityIdentifier("fri.import.link")
                        Button("Read link") { fetchLink() }.disabled(link.isEmpty)
                            .accessibilityIdentifier("fri.import.readLink")
                        Text("The calendar website receives your IP address. FRI reads direct public ICS or structured event links and blocks private networks and redirects.")
                            .friFont(.caption).foregroundStyle(.secondary)
                    }
                    Section("Apple Calendar") {
                        Button("Connect Calendar and review next 7 days") { connectCalendar() }
                            .accessibilityIdentifier("fri.import.connectCalendar")
                        Text("You choose which events to copy. Changes in FRI are saved locally.")
                            .friFont(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    if let binding = items.indices.first {
                        Section {
                            Text(items[binding].notes.isEmpty ? "Confirm the date and time before saving." : items[binding].notes)
                                .friFont(.caption).foregroundStyle(.secondary)
                        } header: { Text("Source evidence") }
                        FRIPlanFields(draft: $items[binding])
                        Button("Add to drafts") { accept() }.buttonStyle(.borderedProminent).tint(FRIColors.marsala).foregroundStyle(FRIColors.cream)
                            .accessibilityIdentifier("fri.import.accept")
                        Button("Skip") { next() }
                            .accessibilityIdentifier("fri.import.skip")
                    }
                }
            }
            .formStyle(.grouped)
            .accessibilityIdentifier("fri.import.form")
            .disabled(busy)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if busy {
                    HStack {
                        ProgressView()
                        Text("Reading source…")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(FRIColors.sidebar)
                } else if let first = notices.first {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(first)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("fri.import.feedback.message")
                        HStack {
                            Button { showFeedback = true } label: {
                                Text("Details").frame(minHeight: 44).contentShape(Rectangle())
                            }
                                .accessibilityIdentifier("fri.import.feedback.details")
                            Spacer()
                            Button { notices = [] } label: {
                                Text("Dismiss").frame(minHeight: 44).contentShape(Rectangle())
                            }
                                .accessibilityIdentifier("fri.import.feedback.dismiss")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FRIColors.sidebar)
                    .overlay(alignment: .top) { Divider() }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("fri.import.feedback")
                }
            }
            .sheet(isPresented: $showFeedback) {
                FRISheetView(title: "Import feedback") {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(Array(notices.enumerated()), id: \.offset) { _, note in
                                Text(note).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                    }
                }
            }
            .onChange(of: notices) { _, messages in
                if let first = messages.first {
                    AccessibilityNotification.Announcement(first).post()
                }
            }
            .fileImporter(isPresented: $pickFile, allowedContentTypes: [.calendarEvent, .commaSeparatedText, .plainText, .pdf, .image], allowsMultipleSelection: true) { result in
                do {
                    let sources = try result.get()
                    run {
                        await Task.detached {
                            var all = ImportResult()
                            for url in sources.prefix(15) {
                                do {
                                    let one = try FRIImportReader.file(url)
                                    all.appointments.append(contentsOf: one.appointments)
                                    all.notices.append(contentsOf: one.notices)
                                } catch {
                                    all.notices.append(url.lastPathComponent + ": " + error.localizedDescription)
                                }
                            }
                            if sources.count > 15 { all.notices.append("Only the first 15 files were read.") }
                            return all
                        }.value
                    }
                } catch { notices = [error.localizedDescription] }
            }
        }
        .onDisappear { operation?.cancel() }
    }

    private func append(_ result: ImportResult) {
        notices = result.notices
        items = result.appointments
        acceptedIDs = []
        if items.isEmpty { notices.append("No new plans found.") }
    }

    private func accept() {
        guard let item = items.first, !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              CalendarClock.date(item.date) != nil else { notices.append("Enter a name and choose a date."); return }
        if calendar.addDrafts([item]) {
            if calendar.state.drafts.contains(where: { $0.id == item.id }) { acceptedIDs.insert(item.id) }
            else { notices.append("This source is already in your calendar or saved drafts.") }
            next()
        }
        else if let message = calendar.message { notices.append(message) }
    }

    private func next() {
        items.removeFirst()
        if items.isEmpty {
            if !acceptedIDs.isEmpty { calendar.reviewDrafts(acceptedIDs) }
            else { notices.append("No new drafts were added.") }
        }
    }

    private func connectCalendar() {
        run {
            guard try await eventStore.requestFullAccessToEvents() else {
                throw FRIImportFailure.calendarPermission
            }
            let clock = CalendarClock.local
            let start = clock.startOfDay(for: .now)
            guard let stop = clock.date(byAdding: .day, value: 7, to: start) else { throw CalendarError.invalidDate }
            let events = eventStore.events(matching: eventStore.predicateForEvents(withStart: start, end: stop, calendars: nil))
            var result = ImportResult()
            result.appointments = events.prefix(500).map { event in
                var item = Appointment()
                item.title = String((event.title ?? "").prefix(160))
                item.date = CalendarClock.day(event.startDate)
                item.location = String((event.location ?? "").prefix(200))
                item.notes = "Source: Apple Calendar · " + String((event.calendar.title).prefix(120))
                item.sourceKey = "eventkit:\(event.calendarItemIdentifier):\(event.startDate.timeIntervalSince1970)"
                if !event.isAllDay {
                    let parts = clock.dateComponents([.hour, .minute], from: event.startDate)
                    item.time = CalendarClock.time((parts.hour ?? 0) * 60 + (parts.minute ?? 0))
                    item.duration = min(1440, max(0, Int(event.endDate.timeIntervalSince(event.startDate) / 60)))
                    PlanImport.clipDuration(&item)
                }
                return item
            }
            return result
        }
    }

    private func fetchLink() {
        let entered = link
        run { try await FRIImportReader.link(entered) }
    }

    private func run(_ action: @escaping @MainActor () async throws -> ImportResult) {
        operation?.cancel()
        notices = []
        busy = true
        operation = Task {
            defer { if !Task.isCancelled { busy = false } }
            do {
                let result = try await action()
                try Task.checkCancellation()
                append(result)
            } catch where !Task.isCancelled { notices = [error.localizedDescription] }
            catch {}
        }
    }
}

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
    static func link(_ entered: String) async throws -> ImportResult {
        let source = try await PublicCalendarSource.read(entered)
        if source.uppercased().contains("BEGIN:VCALENDAR") { return PlanImport.ics(source) }
        return PlanImport.structuredEvents(source)
    }

    static func file(_ url: URL) throws -> ImportResult {
        let scope = url.startAccessingSecurityScopedResource()
        defer { if scope { url.stopAccessingSecurityScopedResource() } }
        let kind = url.pathExtension.lowercased()
        let info = try url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
        let document = kind == "pdf"
        let image = info.contentType?.conforms(to: .image) == true
        let limit = document ? 12 * 1024 * 1024 : (image ? 4 * 1024 * 1024 : 1_048_576)
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
            var result = PlanImport.text(text)
            if pdf.pageCount > 15 { result.notices.append("Only the first 15 PDF pages were read.") }
            return result
        }
        if image {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 2400
                  ] as CFDictionary) else { throw FRIImportFailure.unreadable }
            return PlanImport.text(try recognize(cgImage, orientation: .up))
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: limit + 1) ?? Data()
        guard data.count <= limit, let text = String(data: data, encoding: .utf8) else { throw FRIImportFailure.unreadable }
        if kind == "csv" { return try PlanImport.csv(text) }
        if kind == "ics" { return PlanImport.ics(text) }
        return PlanImport.text(text)
    }

    private static func recognize(_ image: CGImage, orientation: CGImagePropertyOrientation) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        try VNImageRequestHandler(cgImage: image, orientation: orientation).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}
