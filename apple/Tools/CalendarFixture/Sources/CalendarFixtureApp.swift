#if !targetEnvironment(simulator)
#error("The EventKit fixture app must only run in an iOS Simulator.")
#endif

import EventKit
import SwiftUI

@main
struct CalendarFixtureApp: App {
    var body: some Scene { WindowGroup { CalendarFixtureView() } }
}

@MainActor
private struct CalendarFixtureView: View {
    @State private var store = EKEventStore()
    @State private var status = "Ready"
    private let runID = ProcessInfo.processInfo.environment["FRI_CALENDAR_FIXTURE_ID"] ?? ""

    private var name: String { "FRI EventKit QA " + runID }
    private var storageKey: String { "fixture.calendar." + runID }
    private var clock: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = .current
        return value
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Simulator calendar fixture").font(.title)
            Text(runID).font(.caption)
            Text(status).accessibilityIdentifier("fixture.status")
            Button("Prepare calendar") { perform(.prepare) }
            Button("Verify source unchanged") { perform(.verify) }
            Button("Remove calendar") { perform(.remove) }
        }
        .padding()
    }

    private enum Action { case prepare, verify, remove }
    private enum FixtureError: LocalizedError {
        case invalidID, noLocalSource, sourceChanged
        case denied(Int)
        var errorDescription: String? {
            switch self {
            case .invalidID: "Supply a UUID in FRI_CALENDAR_FIXTURE_ID."
            case .denied(let status): "Calendar permission denied (authorization status: \(status))."
            case .noLocalSource: "This Simulator has no local EventKit source."
            case .sourceChanged: "The fixture calendar or its events do not match the expected source."
            }
        }
    }

    private func perform(_ action: Action) {
        status = "Working"
        Task {
            do {
                guard UUID(uuidString: runID) != nil else { throw FixtureError.invalidID }
                if case .remove = action, UserDefaults.standard.string(forKey: storageKey) == nil {
                    status = "Removed QA calendar"
                    return
                }
                guard try await store.requestFullAccessToEvents() else {
                    throw FixtureError.denied(EKEventStore.authorizationStatus(for: .event).rawValue)
                }
                switch action {
                case .prepare: try prepare(); status = "Prepared four events"
                case .verify: try verify(); status = "Source unchanged"
                case .remove: try remove(); status = "Removed QA calendar"
                }
            } catch { status = "Error: " + error.localizedDescription }
        }
    }

    private func prepare() throws {
        guard UserDefaults.standard.string(forKey: storageKey) == nil else { throw FixtureError.sourceChanged }
        guard let source = store.sources.first(where: { $0.sourceType == .local }) else {
            throw FixtureError.noLocalSource
        }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = name
        calendar.source = source
        try store.saveCalendar(calendar, commit: true)
        UserDefaults.standard.set(calendar.calendarIdentifier, forKey: storageKey)
        let day = clock.startOfDay(for: .now)
        for (label, offset, hour, duration, allDay) in [
            ("timed", 1, 9, 45, false), ("all day", 1, 0, 1440, true),
            ("skip", 1, 11, 30, false), ("outside", 8, 9, 30, false)
        ] {
            let event = EKEvent(eventStore: store)
            event.calendar = calendar
            event.title = "FRI QA \(label) \(runID)"
            let date = clock.date(byAdding: .day, value: offset, to: day)!
            event.startDate = clock.date(byAdding: .hour, value: hour, to: date)!
            event.endDate = allDay ? clock.date(byAdding: .day, value: 1, to: date)! : event.startDate.addingTimeInterval(Double(duration * 60))
            event.isAllDay = allDay
            event.location = "QA Room"
            event.notes = "Original QA source notes"
            try store.save(event, span: .thisEvent, commit: true)
        }
        try verify()
    }

    private func ownedCalendar() throws -> EKCalendar {
        guard let id = UserDefaults.standard.string(forKey: storageKey),
              let calendar = store.calendar(withIdentifier: id), calendar.title == name,
              calendar.source.sourceType == .local else { throw FixtureError.sourceChanged }
        return calendar
    }

    private func verify() throws {
        store.reset()
        let calendar = try ownedCalendar()
        let start = clock.startOfDay(for: .now)
        let end = clock.date(byAdding: .day, value: 10, to: start)!
        let events = store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: [calendar]))
        let titles = Set(["timed", "all day", "skip", "outside"].map { "FRI QA \($0) \(runID)" })
        guard events.count == 4, Set(events.map(\.title)) == titles,
              events.allSatisfy({ $0.location == "QA Room" && $0.notes == "Original QA source notes" }),
              let timed = events.first(where: { $0.title == "FRI QA timed \(runID)" }),
              !timed.isAllDay, timed.endDate.timeIntervalSince(timed.startDate) == 2700,
              events.filter(\.isAllDay).count == 1 else { throw FixtureError.sourceChanged }
    }

    private func remove() throws {
        guard UserDefaults.standard.string(forKey: storageKey) != nil else { return }
        store.reset()
        let calendar = try ownedCalendar()
        try store.removeCalendar(calendar, commit: true)
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
