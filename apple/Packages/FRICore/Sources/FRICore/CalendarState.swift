import Foundation

public enum CalendarError: LocalizedError, Sendable {
    case invalidBackup, invalidDate, invalidAppointment, invalidRange
    case missingAppointment, unavailableStore, damagedStore
    case overlap(String)

    public var errorDescription: String? {
        switch self {
        case .invalidBackup: "Choose a valid FRI calendar backup."
        case .invalidDate: "Choose an existing calendar date."
        case .invalidAppointment: "Check the name, time and duration. Appointments must end by midnight."
        case .invalidRange: "Choose valid times within one day."
        case .missingAppointment: "This appointment was deleted."
        case .unavailableStore: "FRI could not open secure calendar storage."
        case .damagedStore: "FRI could not read this calendar. Your data was kept."
        case .overlap(let title): "This time overlaps “\(title)”. Choose a different time."
        }
    }
}

public enum JSONValue: Codable, Equatable, Sendable {
    case string(String), number(Double), bool(Bool), array([Self]), object([String: Self]), null

    public init(from decoder: any Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let bool = try? value.decode(Bool.self) { self = .bool(bool) }
        else if let number = try? value.decode(Double.self) { self = .number(number) }
        else if let string = try? value.decode(String.self) { self = .string(string) }
        else if let items = try? value.decode([Self].self) { self = .array(items) }
        else { self = .object(try value.decode([String: Self].self)) }
    }

    public func encode(to encoder: any Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .string(let string): try value.encode(string)
        case .number(let number): try value.encode(number)
        case .bool(let bool): try value.encode(bool)
        case .array(let items): try value.encode(items)
        case .object(let items): try value.encode(items)
        case .null: try value.encodeNil()
        }
    }

    public var string: String? { if case .string(let value) = self { value } else { nil } }
    public var bool: Bool? { if case .bool(let value) = self { value } else { nil } }
}

public enum CalendarClock {
    public static var local: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }

    public static func day(_ date: Date = .now, calendar: Calendar = local) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    public static func date(_ day: String, calendar: Calendar = local) -> Date? {
        guard day.utf8.count == 10,
              day.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"#, options: .regularExpression) != nil
        else { return nil }
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, parts[0] > 0,
              let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)),
              Self.day(date, calendar: calendar) == day else { return nil }
        return date
    }

    public static func minutes(_ time: String) -> Int? {
        guard time.utf8.count == 5,
              time.range(of: #"^[0-9]{2}:[0-9]{2}$"#, options: .regularExpression) != nil,
              let hour = Int(time.prefix(2)), let minute = Int(time.suffix(2)),
              hour < 24, minute < 60 else { return nil }
        return hour * 60 + minute
    }

    public static func time(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}

public struct Appointment: Codable, Identifiable, Equatable, Sendable {
    public var id: String = UUID().uuidString
    public var title = ""
    public var date = CalendarClock.day()
    public var time = ""
    public var duration = 0
    public var category = "Personal"
    public var location = ""
    public var notes = ""
    public var done = false
    public var kind: String?
    public var sourceKey: String?

    public init() {}

    public var isDeadline: Bool { kind == "deadline" }

    public var endMinute: Int? { CalendarClock.minutes(time).map { $0 + duration } }

    public func validate(draft: Bool = false) throws {
        guard id.utf8.count <= 100,
              id.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil,
              (draft || !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty),
              title.utf16.count <= 160, category.utf16.count <= 35,
              location.utf16.count <= 200, notes.utf16.count <= 2000,
              (0...1440).contains(duration), !isDeadline || duration == 0,
              (draft && date.isEmpty) || CalendarClock.date(date) != nil,
              (draft && time.isEmpty) || (endMinute ?? 1441) <= 1440
        else { throw CalendarError.invalidAppointment }
    }

    public func conflict(in tasks: [Self]) -> Self? {
        guard let begin = CalendarClock.minutes(time), duration > 0, !isDeadline else { return nil }
        return tasks.first { task in
            guard task.id != id, task.date == date, !task.isDeadline, task.duration > 0,
                  let other = CalendarClock.minutes(task.time) else { return false }
            return begin < other + task.duration && other < begin + duration
        }
    }
}

public struct CalendarState: Codable, Equatable, Sendable {
    public var version = 1
    public var tasks: [Appointment] = []
    public var drafts: [Appointment] = []
    public var tabs: [String] = []
    public var active = CalendarClock.day()
    public var settings: [String: JSONValue] = [:]
    public var widgets: [JSONValue] = []
    public var collections: [JSONValue] = []
    public var finished: [JSONValue] = []

    public init() {}

    private enum CodingKeys: CodingKey { case version, tasks, drafts, tabs, active, settings, widgets, collections, finished }

    public init(from decoder: any Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        tasks = try values.decode([Appointment].self, forKey: .tasks)
        drafts = try values.decodeIfPresent([Appointment].self, forKey: .drafts) ?? []
        tabs = try values.decodeIfPresent([String].self, forKey: .tabs) ?? []
        active = try values.decodeIfPresent(String.self, forKey: .active) ?? CalendarClock.day()
        settings = try values.decodeIfPresent([String: JSONValue].self, forKey: .settings) ?? [:]
        widgets = try values.decodeIfPresent([JSONValue].self, forKey: .widgets) ?? []
        collections = try values.decodeIfPresent([JSONValue].self, forKey: .collections) ?? []
        finished = try values.decodeIfPresent([JSONValue].self, forKey: .finished) ?? []
    }

    public func validate() throws {
        guard version == 1, tasks.count <= 10_000, drafts.count <= 10_000,
              Set(tasks.map(\.id)).count == tasks.count,
              Set(drafts.map(\.id)).count == drafts.count,
              CalendarClock.date(active) != nil,
              tabs.allSatisfy({ CalendarClock.date($0) != nil }) else { throw CalendarError.invalidBackup }
        for task in tasks { try task.validate() }
        for draft in drafts { try draft.validate(draft: true) }
        guard try JSONEncoder().encode(self).count <= CalendarBackup.sizeLimit else { throw CalendarError.invalidBackup }
    }

    public func tasks(on day: String) -> [Appointment] {
        tasks.filter { $0.date == day }.sorted { ($0.time, $0.id) < ($1.time, $1.id) }
    }
}

public struct CalendarBackup: Codable, Sendable {
    public static let sizeLimit = 8 * 1024 * 1024
    public let format: String
    public let schema: Int
    public let state: CalendarState

    public static func export(_ state: CalendarState) throws -> Data {
        try state.validate()
        let data = try JSONEncoder().encode(Self(format: "fri-backup", schema: 1, state: state))
        guard data.count <= sizeLimit else { throw CalendarError.invalidBackup }
        return data
    }

    public static func read(_ data: Data) throws -> CalendarState {
        guard data.count <= sizeLimit,
              let object = try? JSONSerialization.jsonObject(with: data), validKeys(object),
              let backup = try? JSONDecoder().decode(Self.self, from: data),
              backup.format == "fri-backup", backup.schema == 1 else { throw CalendarError.invalidBackup }
        try backup.state.validate()
        return backup.state
    }

    private static func validKeys(_ value: Any) -> Bool {
        if let object = value as? [String: Any] {
            return object.allSatisfy {
                !["__proto__", "constructor", "prototype"].contains($0.key) && validKeys($0.value)
            }
        }
        if let list = value as? [Any] { return list.allSatisfy(validKeys) }
        return true
    }
}
