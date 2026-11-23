import Foundation

public struct ImportResult: Sendable {
    public var appointments: [Appointment] = []
    public var notices: [String] = []
    public init() {}
}

public enum PlanImport {
    public static func text(_ source: String) -> ImportResult {
        var output = ImportResult()
        for line in source.split(whereSeparator: \.isNewline).prefix(500) {
            let string = String(line).trimmingCharacters(in: .whitespaces)
            if string.isEmpty { continue }
            let date = string.range(of: #"\b[0-9]{4}-[0-9]{2}-[0-9]{2}\b"#, options: .regularExpression)
            let time = string.range(of: #"\b[0-9]{2}:[0-9]{2}\b"#, options: .regularExpression)
            var item = Appointment()
            item.date = date.map { String(string[$0]) }.flatMap { CalendarClock.date($0) == nil ? nil : $0 } ?? ""
            item.time = time.map { String(string[$0]) }.flatMap { CalendarClock.minutes($0) == nil ? nil : $0 } ?? ""
            let title = string.replacingOccurrences(of: #"\b[0-9]{4}-[0-9]{2}-[0-9]{2}\b|\b[0-9]{2}:[0-9]{2}\b"#, with: "", options: .regularExpression)
            item.title = String(title.trimmingCharacters(in: .whitespaces).prefix(160))
            item.notes = String(("Source: " + string).prefix(2000))
            item.kind = "schedule"
            output.appointments.append(item)
        }
        return output
    }

    public static func csv(_ source: String) throws -> ImportResult {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var characters = source.makeIterator()
        var next = characters.next()
        while let char = next {
            next = characters.next()
            if char == "\"" {
                if quoted && next == "\"" {
                    field.append(char)
                    next = characters.next()
                } else if quoted || field.isEmpty { quoted.toggle() }
                else { throw CalendarError.invalidAppointment }
            } else if !quoted && (char == "," || char.isNewline) {
                row.append(field)
                field = ""
                if char.isNewline {
                    rows.append(row)
                    row = []
                }
            } else { field.append(char) }
        }
        guard !quoted else { throw CalendarError.invalidAppointment }
        if !field.isEmpty || !row.isEmpty { rows.append(row + [field]) }
        guard let header = rows.first else { return ImportResult() }
        let keys = header.map { $0.replacingOccurrences(of: "\u{feff}", with: "").trimmingCharacters(in: .whitespaces).lowercased() }
        guard keys.contains("title") else { throw CalendarError.invalidAppointment }
        var output = ImportResult()
        for row in rows.dropFirst().prefix(500) where row.contains(where: { !$0.isEmpty }) {
            func value(_ key: String) -> String {
                guard let index = keys.firstIndex(of: key), row.indices.contains(index) else { return "" }
                return row[index]
            }
            var item = Appointment()
            item.title = String(value("title").prefix(160))
            item.date = CalendarClock.date(value("date")) != nil ? value("date") : ""
            item.time = CalendarClock.minutes(value("time")) != nil ? value("time") : ""
            item.kind = value("kind") == "deadline" ? "deadline" : "schedule"
            let duration = Int(value("duration")) ?? 0
            item.duration = !item.isDeadline && (1...1440).contains(duration) ? duration : 0
            item.location = String(value("location").prefix(200))
            item.notes = String(value("notes").prefix(2000))
            clipDuration(&item)
            output.appointments.append(item)
        }
        if rows.count > 501 { output.notices.append("Only the first 500 rows were read.") }
        return output
    }

    public static func ics(_ source: String, calendar: Calendar = CalendarClock.local) -> ImportResult {
        struct Property {
            let value: String
            let zone: String?
            var compactDate: String {
                let day = value.prefix(8)
                guard day.count == 8 else { return "" }
                return "\(day.prefix(4))-\(day.dropFirst(4).prefix(2))-\(day.suffix(2))"
            }
        }
        struct Candidate {
            let sequence: Int
            let item: Appointment?
        }
        var ordered: [String] = []
        var events: [String: Candidate] = [:]
        var output = ImportResult()
        var lines: [String] = []
        let separator = source.replacingOccurrences(of: "\r\n", with: "\n")
        for line in separator.split(separator: "\n") {
            if (line.first == " " || line.first == "\t"), !lines.isEmpty {
                lines[lines.count - 1] += line.dropFirst()
            } else { lines.append(String(line)) }
        }
        var context: String?
        var nested = 0
        var record: [String: Property] = [:]
        func instant(_ property: Property) -> Date? {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.isLenient = false
            let utc = property.value.hasSuffix("Z")
            let discardedSuffix = utc ? String(property.value.dropLast()) : property.value
            if utc { formatter.timeZone = TimeZone(secondsFromGMT: 0) }
            else if let zone = property.zone {
                guard let timeZone = TimeZone(identifier: zone.trimmingCharacters(in: CharacterSet(charactersIn: "\""))) else { return nil }
                formatter.timeZone = timeZone
            } else { formatter.timeZone = calendar.timeZone }
            formatter.dateFormat = "yyyyMMdd'T'HHmmss"
            guard discardedSuffix.count == 15, let date = formatter.date(from: discardedSuffix),
                  formatter.string(from: date) == discardedSuffix else { return nil }
            if !utc, [date.addingTimeInterval(-3600), date.addingTimeInterval(3600)].contains(where: {
                formatter.string(from: $0) == discardedSuffix
            }) { return nil }
            return date
        }

        for line in lines {
            let upper = line.uppercased()
            if context == nil, upper == "BEGIN:VEVENT" || upper == "BEGIN:VTODO" {
                context = String(upper.dropFirst("BEGIN:".count))
                record = [:]
                nested = 0
                continue
            }
            guard let event = context else { continue }
            if upper == "END:" + event, nested == 0 {
                context = nil
                let uid = record["UID"]?.value ?? UUID().uuidString
                let key = uid + "|" + (record["RECURRENCE-ID"]?.value ?? "")
                let revision = Int(record["SEQUENCE"]?.value ?? "") ?? 0
                if let old = events[key], old.sequence > revision { continue }
                if events[key] == nil { ordered.append(key) }
                if record["STATUS"]?.value.uppercased() == "CANCELLED" {
                    events[key] = Candidate(sequence: revision, item: nil)
                    continue
                }
                let due = event == "VTODO" ? record["DUE"] : nil
                let start = due ?? record["DTSTART"]
                var item = Appointment()
                item.title = String(unescape(record["SUMMARY"]?.value ?? "").prefix(160))
                item.date = start?.compactDate ?? ""
                if CalendarClock.date(item.date, calendar: calendar) == nil { item.date = "" }
                item.kind = due == nil ? "schedule" : "deadline"
                item.sourceKey = String(("ics:" + key).prefix(500))
                item.location = String(unescape(record["LOCATION"]?.value ?? "").prefix(200))
                item.notes = String(unescape(record["DESCRIPTION"]?.value ?? "").prefix(1200))
                if let start {
                    item.notes += "\nSource: " + String(start.value.prefix(100))
                    if let point = instant(start) {
                        item.date = CalendarClock.day(point, calendar: calendar)
                        let components = calendar.dateComponents([.hour, .minute], from: point)
                        item.time = CalendarClock.time((components.hour ?? 0) * 60 + (components.minute ?? 0))
                        if !item.isDeadline, let property = record["DTEND"], let end = instant(property),
                           end.timeIntervalSince(point) > 0, end.timeIntervalSince(point) <= 86_400 {
                            item.duration = Int(end.timeIntervalSince(point) / 60)
                        }
                    } else if start.value.count > 8, !output.notices.contains("Some times require review because the timezone or local time is ambiguous.") {
                        output.notices.append("Some times require review because the timezone or local time is ambiguous.")
                    }
                }
                if record["RRULE"] != nil, !output.notices.contains("Recurring events include only occurrences present in the file.") {
                    output.notices.append("Recurring events include only occurrences present in the file.")
                }
                clipDuration(&item)
                events[key] = Candidate(sequence: revision, item: item)
                continue
            }
            if upper.hasPrefix("BEGIN:") { nested += 1; continue }
            if upper.hasPrefix("END:"), nested > 0 { nested -= 1; continue }
            guard nested == 0, let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].split(separator: ";")
            let zone = name.dropFirst().first { $0.uppercased().hasPrefix("TZID=") }.map { String($0.dropFirst(5)) }
            if let first = name.first {
                record[first.uppercased()] = Property(value: String(line[line.index(after: colon)...]), zone: zone)
            }
        }
        output.appointments = ordered.compactMap { events[$0]?.item }.prefix(500).map { $0 }
        if ordered.count > 500 { output.notices.append("Only the first 500 calendar items were read.") }
        return output
    }

    private static func unescape(_ value: String) -> String {
        value.replacingOccurrences(of: #"\n"#, with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: #"\,"#, with: ",")
            .replacingOccurrences(of: #"\;"#, with: ";")
            .replacingOccurrences(of: #"\\"#, with: "\\")
    }

    public static func clipDuration(_ item: inout Appointment) {
        if let minute = CalendarClock.minutes(item.time), item.duration > 1440 - minute { item.duration = 0 }
    }
}
