import Foundation

public enum Planning {
    public static func free(in tasks: [Appointment], day: String, start: Int = 540, end: Int = 1080) -> [Range<Int>] {
        guard (0..<1440).contains(start), end > start, end <= 1440 else { return [] }
        let busy = tasks.compactMap { task -> Range<Int>? in
            guard task.date == day, !task.isDeadline, task.duration > 0,
                  let lower = CalendarClock.minutes(task.time) else { return nil }
            return lower..<(lower + task.duration)
        }.sorted { $0.lowerBound < $1.lowerBound }
        var result: [Range<Int>] = []
        var cursor = start
        for time in busy where time.lowerBound < end && time.upperBound > cursor {
            if time.lowerBound > cursor { result.append(cursor..<time.lowerBound) }
            cursor = max(cursor, time.upperBound)
        }
        if cursor < end { result.append(cursor..<end) }
        return result
    }

    public struct Availability: Codable, Sendable {
        public struct Window: Codable, Equatable, Hashable, Sendable {
            public let start: String
            public let end: String
        }

        public let format: String
        public let version: Int
        public let generatedAt: String?
        public let windows: [Window]

        public static func export(_ tasks: [Appointment], day: String, days: Int = 7, calendar: Calendar = CalendarClock.local) throws -> Data {
            guard (1...31).contains(days), let first = CalendarClock.date(day, calendar: calendar) else {
                throw CalendarError.invalidDate
            }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let windows = (0..<days).flatMap { offset -> [Window] in
                guard let date = calendar.date(byAdding: .day, value: offset, to: first) else { return [] }
                return Planning.free(in: tasks, day: CalendarClock.day(date, calendar: calendar)).compactMap { window in
                    guard let start = calendar.date(bySettingHour: window.lowerBound / 60, minute: window.lowerBound % 60, second: 0, of: date),
                          let end = calendar.date(bySettingHour: window.upperBound / 60, minute: window.upperBound % 60, second: 0, of: date),
                          start < end else { return nil }
                    return Window(start: formatter.string(from: start), end: formatter.string(from: end))
                }
            }
            return try JSONEncoder().encode(Self(format: "fri-free-time", version: 1, generatedAt: formatter.string(from: .now), windows: windows))
        }

        public static func compare(_ local: Data, _ external: Data, duration: Int = 30) throws -> [DateInterval] {
            guard (1...1440).contains(duration) else { throw CalendarError.invalidRange }
            let plain = ISO8601DateFormatter()
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            func intervals(_ data: Data) throws -> [DateInterval] {
                guard data.count <= 1_000_000 else { throw CalendarError.invalidRange }
                let file = try JSONDecoder().decode(Self.self, from: data)
                guard file.format == "fri-free-time", file.version == 1, file.windows.count <= 1_000 else {
                    throw CalendarError.invalidRange
                }
                return try file.windows.map { window in
                    guard let start = fractional.date(from: window.start) ?? plain.date(from: window.start),
                          let end = fractional.date(from: window.end) ?? plain.date(from: window.end),
                          end > start, end.timeIntervalSince(start) <= 86_400 else { throw CalendarError.invalidRange }
                    return DateInterval(start: start, end: end)
                }
            }

            let remote = try intervals(external)
            var matches = Set<DateInterval>()
            for first in try intervals(local) {
                for second in remote {
                    let start = max(first.start, second.start)
                    let end = min(first.end, second.end)
                    if end.timeIntervalSince(start) >= Double(duration * 60) {
                        matches.insert(DateInterval(start: start, end: end))
                    }
                }
            }
            return matches.sorted { ($0.start, $0.end) < ($1.start, $1.end) }
        }
    }
}
