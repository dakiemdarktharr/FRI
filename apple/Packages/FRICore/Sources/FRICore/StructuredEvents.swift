import CryptoKit
import Foundation

extension PlanImport {
    public static func structuredEvents(_ source: String, calendar: Calendar = CalendarClock.local) -> ImportResult {
        let script = try? NSRegularExpression(
            pattern: #"<script\b[^>]*\btype\s*=\s*["']application/ld\+json["'][^>]*>([\s\S]*?)</script\s*>"#,
            options: .caseInsensitive
        )
        let scripts = script?.matches(in: source, range: NSRange(source.startIndex..., in: source)).prefix(50).compactMap {
            Range($0.range(at: 1), in: source).map { String(source[$0]) }
        } ?? []
        let input = scripts.isEmpty ? [source] : scripts
        var nodes = input.compactMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) }
        var result = ImportResult()
        let zoned = ISO8601DateFormatter()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        func eventTime(_ value: String) -> (day: String, time: String, instant: Date?)? {
            let day = String(value.prefix(10))
            guard CalendarClock.date(day, calendar: calendar) != nil else { return nil }
            let timestamp = value.replacingOccurrences(of: " ", with: "T")
            if let instant = zoned.date(from: timestamp) ?? fractional.date(from: timestamp) {
                let parts = calendar.dateComponents([.hour, .minute], from: instant)
                return (CalendarClock.day(instant, calendar: calendar),
                        CalendarClock.time((parts.hour ?? 0) * 60 + (parts.minute ?? 0)), instant)
            }
            return (day, "", nil)
        }

        var visited = 0
        while visited < nodes.count, visited < 3000, result.appointments.count < 500 {
            let raw = nodes[visited]
            visited += 1
            guard let node = raw as? [String: Any] else {
                if let group = raw as? [Any] { nodes.append(contentsOf: group.prefix(max(0, 3000 - nodes.count))) }
                continue
            }
            let types = (node["@type"] as? [String]) ?? (node["@type"] as? String).map { [$0] } ?? []
            guard types.contains(where: { $0.hasSuffix("Event") }),
                  let name = node["name"] as? String, let startValue = node["startDate"] as? String,
                  let start = eventTime(startValue) else {
                let children = node.values.filter { $0 is [String: Any] || $0 is [Any] }
                nodes.append(contentsOf: children.prefix(max(0, 3000 - nodes.count)))
                continue
            }
            if (node["eventStatus"] as? String)?.hasSuffix("EventCancelled") == true { continue }
            let location = node["location"] as? String ?? (node["location"] as? [String: Any])?["name"] as? String ?? ""
            var item = Appointment()
            item.kind = "schedule"
            item.title = String(name.prefix(160))
            item.date = start.day
            item.time = start.time
            item.location = String(location.prefix(200))
            let endValue = node["endDate"] as? String
            if let startTime = start.instant, let endValue, let endTime = eventTime(endValue)?.instant {
                let duration = endTime.timeIntervalSince(startTime)
                if duration > 0, duration <= 86_400 { item.duration = Int(duration / 60) }
            }
            clipDuration(&item)
            item.notes = "Source: " + String(startValue.prefix(120)) + (endValue.map { " to " + String($0.prefix(120)) } ?? "")
            let sourceID = (node["@id"] as? String) ?? (node["identifier"] as? String) ?? (node["url"] as? String)
            let digest = SHA256.hash(data: Data([name, startValue, location].joined(separator: "|").utf8))
            item.sourceKey = "event:" + String((sourceID ?? digest.map { String(format: "%02x", $0) }.joined()).prefix(500))
            result.appointments.append(item)
        }
        return result
    }
}
