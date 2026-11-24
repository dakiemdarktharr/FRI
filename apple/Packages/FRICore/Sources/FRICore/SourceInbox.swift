import Foundation
import JavaScriptCore

public typealias SourceRow = [String: JSONValue]

public struct PreparedSource: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var label: String
    public var rows: [SourceRow]
    public var links: [String]?
    public var status: String?
    public var settings: SourceRow?
    public var warnings: [String]?

    public init(label: String, rows: [SourceRow], links: [String] = [], warnings: [String] = []) {
        let batchID = UUID().uuidString
        id = batchID
        self.label = label
        self.rows = rows.enumerated().map { index, entry in
            var row = entry
            if row["sourceKey"]?.string?.isEmpty != false { row["sourceKey"] = .string("inbox-\(batchID)-\(index)") }
            return row
        }
        settings = ["workStart": .number(540), "workEnd": .number(1080), "sessionMinutes": .number(60), "breakMinutes": .number(10)]
        status = "ready"
        self.links = links
        self.warnings = warnings
    }
}

public struct SavedSource: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var label: String
    public var links: [String]?
    public var readAt: Double?
}

public struct SourceRead: Decodable, Sendable {
    public var rows: [SourceRow]
    public var warnings: [String]
    public init(rows: [SourceRow] = [], warnings: [String] = []) {
        self.rows = rows
        self.warnings = warnings
    }
}

public struct SourceFailure: LocalizedError {
    public var errorDescription: String? { reason }
    public let reason: String
    public init(_ reason: String) { self.reason = reason }
}

/// Calls only bundled calendar logic. Source text is a JS argument, never executable script.
public final class SourcePlanner {
    private let context: JSContext

    public init() throws {
        guard let js = JSContext() else { throw SourceFailure("Calendar reader unavailable.") }
        context = js
        js.evaluateScript("var window = globalThis;")
        try load("import-plan", ext: "cjs")
        try load("inbox", ext: "cjs")
    }

    private func load(_ name: String, ext: String) throws {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext) else {
            throw SourceFailure("Missing calendar reader: " + name)
        }
        context.evaluateScript(try String(contentsOf: url, encoding: .utf8), withSourceURL: url)
        try check()
    }

    public func documentText(_ bytes: Data) throws -> String {
        guard bytes.count <= 8 * 1024 * 1024 else { throw SourceFailure("Choose a document under 8 MB.") }
        try load("document-reader", ext: "js")
        // Pass file bytes across the Objective-C bridge as one bounded string.
        let xml: String = try call("FriDocument", "documentXML", [bytes.base64EncodedString()], as: String.self)
        let collector = WordText()
        let parser = XMLParser(data: Data(xml.utf8))
        parser.shouldResolveExternalEntities = false
        parser.delegate = collector
        guard parser.parse() else { throw SourceFailure("Invalid Word document XML.") }
        return collector.text
    }

    private func check() throws {
        if let exception = context.exception {
            let message = exception.toString() ?? "Could not read this source."
            context.exception = nil
            throw SourceFailure(message)
        }
    }

    private func call<T: Decodable>(_ object: String, _ method: String, _ args: [Any], as type: T.Type) throws -> T {
        let result = context.objectForKeyedSubscript(object)?.invokeMethod(method, withArguments: args)
        try check()
        guard let result else { throw SourceFailure("No result from the source reader.") }
        let json = context.objectForKeyedSubscript("JSON")?.invokeMethod("stringify", withArguments: [result])?.toString()
        try check()
        guard let json else { throw SourceFailure("Invalid source record.") }
        return try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    private func argument<T: Encodable>(_ value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
    }

    public func read(_ text: String, name: String = "") throws -> SourceRead {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().hasPrefix("BEGIN:VCALENDAR") {
            struct CalendarResult: Decodable { var events: [SourceRow]; var warnings: [String] }
            try load("calendar-reader", ext: "js")
            let parsed = try call("FriCalendarSource", "parseCalendar", [text], as: CalendarResult.self)
            return SourceRead(rows: parsed.events, warnings: parsed.warnings)
        }
        if name.lowercased().hasSuffix(".ics") { throw SourceFailure("Invalid calendar file.") }
        var result = try call("FriInbox", "parse", [text, name], as: SourceRead.self)
        if result.rows.isEmpty && name.isEmpty {
            result.rows = try call("FriImport", "plain", [text], as: [SourceRow].self)
        }
        return result
    }

    public func normalized(_ row: SourceRow) throws -> SourceRow {
        try call("FriImport", "normalize", [argument(row)], as: SourceRow.self)
    }

    public func question(_ row: SourceRow) throws -> [String]? {
        try call("FriImport", "missing", [argument(row)], as: [String]?.self)
    }

    public func past(_ row: SourceRow, now: Date = .now) throws -> Bool {
        try call("FriImport", "past", [argument(row), now.timeIntervalSince1970 * 1000], as: Bool.self)
    }

    public func refresh(_ state: inout CalendarState, now: Date = .now) throws -> (added: Int, held: Int, skipped: Int) {
        struct Result: Decodable { var tasks: [Appointment]; var remaining: [PreparedSource]; var skipped: [SourceRow] }
        let plan = try call("FriInbox", "prepare", [argument(state.importQueue), argument(state.tasks),
                                                    ["now": now.timeIntervalSince1970 * 1000]], as: Result.self)
        state.tasks.append(contentsOf: plan.tasks)
        let reopened = Set(plan.tasks.map(\.date))
        state.finished.removeAll { $0.string.map(reopened.contains) ?? false }
        state.importQueue = plan.remaining
        return (plan.tasks.count, plan.remaining.reduce(0) { $0 + $1.rows.count }, plan.skipped.count)
    }
}

public extension CalendarState {
    mutating func stageSource(_ batch: PreparedSource, now: Date = .now) throws {
        guard !batch.rows.isEmpty, batch.rows.count <= 500,
              importQueue.reduce(batch.rows.count, { $0 + $1.rows.count }) <= 1000 else {
            throw SourceFailure("Prepare 1–500 plans per source and refresh before accumulating over 1,000 plans.")
        }
        importQueue.append(batch)
        sourceLibrary.insert(SavedSource(id: batch.id, label: batch.label, links: batch.links, readAt: now.timeIntervalSince1970 * 1000), at: 0)
        sourceLibrary = Array(sourceLibrary.prefix(100))
    }
}

private final class WordText: NSObject, XMLParserDelegate {
    var text = ""
    private var inText = false
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String]) {
        inText = elementName == "w:t"
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { if inText { text += string } }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        inText = false
        if elementName == "w:p" { text += "\n" }
    }
}
