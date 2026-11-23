import CryptoKit
import Foundation
import Testing
@testable import FRICore

private func task(_ title: String, time: String, duration: Int) -> Appointment {
    var item = Appointment()
    item.title = title
    item.date = "2026-11-23"
    item.time = time
    item.duration = duration
    item.kind = duration == 0 ? "deadline" : "schedule"
    return item
}

private func withStore(_ action: (CalendarStore, URL) async throws -> Void) async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let key = SymmetricKey(size: .bits256)
    let store = CalendarStore(directory: directory) { _ in key }
    try await action(store, directory)
}

@Test func datesAndDurationsMatchFRI() throws {
    #expect(CalendarClock.date("2024-02-29") != nil)
    #expect(CalendarClock.date("2026-02-29") == nil)
    #expect(CalendarClock.minutes("24:00") == nil)
    let early = task("Early", time: "08:00", duration: 120)
    let overlap = task("Overlap", time: "09:30", duration: 90)
    let adjacent = task("Adjacent", time: "11:00", duration: 60)
    let deadline = task("Deadline", time: "12:00", duration: 0)
    #expect(overlap.conflict(in: [early]) == early)
    #expect(adjacent.conflict(in: [overlap]) == nil)
    #expect(Planning.free(in: [early, overlap, deadline], day: early.date) == [660..<1080])
    #expect(throws: CalendarError.self) { try task("Crosses midnight", time: "23:59", duration: 2).validate() }
}

@Test func availabilityWireFormatAndOffsets() throws {
    var vietnam = Calendar(identifier: .gregorian)
    vietnam.timeZone = try #require(TimeZone(secondsFromGMT: 25_200))
    let local = try Planning.Availability.export([task("Secret title", time: "10:00", duration: 60)],
                                                  day: "2026-11-23", days: 1, calendar: vietnam)
    #expect(!String(decoding: local, as: UTF8.self).contains("Secret"))
    let other = """
    {"format":"fri-free-time","version":1,"windows":[{"start":"2026-11-23T09:30:00+07:00","end":"2026-11-23T03:00:00Z"}]}
    """
    let matches = try Planning.Availability.compare(local, Data(other.utf8))
    #expect(matches.count == 1)
    #expect(matches.first?.duration == 1800)
}

@Test func backupKeepsSettingsDraftsAndLegacyTasks() throws {
    let windows = """
    {"format":"fri-backup","schema":1,"state":{"version":1,
    "tasks":[{"id":"sample-1","title":"Legacy","date":"2026-11-23","time":"09:00","duration":60,
    "category":"Work","location":"","notes":"","done":false}],
    "tabs":["2026-11-23"],"active":"2026-11-23","drafts":[],
    "settings":{"desktopWidgets":[{"x":3,"y":7}],"futureOption":true}}}
    """
    var state = try CalendarBackup.read(Data(windows.utf8))
    #expect(state.tasks.first?.isDeadline == false)
    #expect(state.settings["futureOption"] == .bool(true))
    #expect(state.active == "2026-11-23")
    var draft = task("Draft", time: "", duration: 60)
    draft.kind = "schedule"
    state.drafts = [draft]
    let data = try CalendarBackup.export(state)
    #expect(try CalendarBackup.read(data) == state)
    let unsafe = windows.replacingOccurrences(of: "futureOption", with: "__proto__")
    #expect(throws: CalendarError.self) { try CalendarBackup.read(Data(unsafe.utf8)) }
}

@Test func concurrentCompletionAndEditPreserveBothWrites() async throws {
    try await withStore { store, _ in
        let item = task("Original", time: "10:00", duration: 30)
        #expect(try store.read().revision == 0)
        try store.update { $0.tasks.append(item) }
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try store.complete(item.id) }
            group.addTask { try store.update { $0.tasks[0].title = "Edited" } }
            group.addTask { try store.complete(item.id) }
            try await group.waitForAll()
        }
        let saved = try store.read()
        #expect(saved.revision == 3)
        #expect(saved.state.tasks.first?.done == true)
        #expect(saved.state.tasks.first?.title == "Edited")
        try store.update { $0.tasks.removeAll() }
        #expect(throws: CalendarError.self) { try store.complete(item.id) }
        #expect(try store.read().state.tasks.isEmpty)
    }
}

@Test func encryptedRestoreAndDamagedFileFailClosed() async throws {
    try await withStore { store, directory in
        let original = task("Original secret", time: "10:00", duration: 30)
        try store.update { $0.tasks = [original] }
        var replacement = CalendarState()
        replacement.tasks = [task("Replacement secret", time: "14:00", duration: 40)]
        #expect(try store.restore(replacement).restored.state.tasks == replacement.tasks)
        let before = try Data(contentsOf: directory.appending(path: "pre-restore.v1.aesgcm"))
        #expect(before.range(of: Data(original.title.utf8)) == nil)
        let file = directory.appending(path: "calendar.v1.aesgcm")
        let damaged = Data([1, 2, 3, 4])
        try damaged.write(to: file)
        #expect(throws: CalendarError.self) { try store.update { $0.tasks = [] } }
        #expect(try Data(contentsOf: file) == damaged)
    }
}

@Test func deniedKeychainPreparationPreservesExistingCalendar() async throws {
    try await withStore { store, directory in
        let item = task("Keep this calendar", time: "10:00", duration: 30)
        try store.update { $0.tasks = [item] }
        let file = directory.appending(path: "calendar.v1.aesgcm")
        let original = try Data(contentsOf: file)
        let denied = CalendarStore(directory: directory) { _ in throw CalendarError.unavailableStore }
        #expect(throws: CalendarError.self) { try denied.prepare() }
        #expect(try Data(contentsOf: file) == original)
        #expect(try store.prepare().state.tasks == [item])
    }
}

@Test func initialPreparationRequiresKeyBeforeAcceptingEmptyCalendar() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let denied = CalendarStore(directory: directory) { _ in throw CalendarError.unavailableStore }
    #expect(throws: CalendarError.self) { try denied.prepare() }
    #expect(!FileManager.default.fileExists(atPath: directory.appending(path: "calendar.v1.aesgcm").path))
    let permitted = CalendarStore(directory: directory) { mayCreate in
        guard mayCreate else { throw CalendarError.unavailableStore }
        return SymmetricKey(data: Data(repeating: 1, count: 32))
    }
    #expect(try permitted.prepare().revision == 0)
}

@Test func calendarImportUnfoldsRetainsAllDayAndFlagsAmbiguousTimes() throws {
    let source = """
    BEGIN:VCALENDAR
    BEGIN:VEVENT
    UID:a
    SEQUENCE:0
    DTSTART;VALUE=DATE:20261123
    SUMMARY:Old
    END:VEVENT
    BEGIN:VEVENT
    UID:a
    SEQUENCE:1
    DTSTART;VALUE=DATE:20261123
    RRULE:FREQ=WEEKLY
    SUMMARY:Team
     lunch
    END:VEVENT
    BEGIN:VEVENT
    UID:b
    DTSTART;TZID=America/New_York:20261101T013000
    SUMMARY:Ambiguous
    END:VEVENT
    BEGIN:VEVENT
    UID:c
    DTSTART;TZID=America/New_York:20260308T023000
    SUMMARY:Skipped
    END:VEVENT
    END:VCALENDAR
    """
    let result = PlanImport.ics(source)
    #expect(result.appointments.map(\.title) == ["Teamlunch", "Ambiguous", "Skipped"])
    #expect(result.appointments.allSatisfy { $0.time.isEmpty })
    #expect(result.appointments.first?.date == "2026-11-23")
    #expect(result.notices.count == 2)
}

@Test func csvAndTextPreserveReviewInputs() throws {
    let source = "title,date,time,duration\r\n\"Read, then write\",2026-11-23,09:15,35"
    let result = try PlanImport.csv(source)
    #expect(result.appointments.first?.title == "Read, then write")
    #expect(result.appointments.first?.duration == 35)
    let text = PlanImport.text("Take a walk 2026-11-23")
    #expect(text.appointments.first?.time == "")
    #expect(text.appointments.first?.date == "2026-11-23")
}

@Test func publicSourcesRejectPrivateAddressesAndInvalidHTTP() throws {
    for address in ["10.0.0.1", "127.0.0.1", "169.254.169.254", "192.168.1.1", "198.18.0.1",
                    "::1", "::ffff:192.168.1.1", "fe80::1", "2001:db8::1", "fc00::1"] {
        #expect(!PublicCalendarSource.isPublic(address))
    }
    #expect(PublicCalendarSource.isPublic("8.8.8.8"))
    #expect(PublicCalendarSource.isPublic("2606:4700::1111"))
    let chunked = Data("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n4\r\nTest\r\n0\r\n\r\n".utf8)
    #expect(try PublicCalendarSource.decodeResponse(chunked) == "Test")
    let redirect = Data("HTTP/1.1 302 Found\r\nLocation: https://example.com\r\n\r\n".utf8)
    #expect(throws: PublicCalendarSource.Failure.self) { try PublicCalendarSource.decodeResponse(redirect) }
    let partial = Data("HTTP/1.1 200 OK\r\nContent-Length: 100\r\n\r\nPartial".utf8)
    #expect(throws: PublicCalendarSource.Failure.self) { try PublicCalendarSource.decodeResponse(partial) }
}

@Test func structuredEventsKeepSourceEvidenceAndRequireReviewForFloatingTime() throws {
    let source = """
    <script type="application/ld+json">
    {"@graph":[{"@type":"MusicEvent","name":"Concert","startDate":"2026-11-23T17:00:00+07:00",
    "endDate":"2026-11-23T18:00:00+07:00","location":{"name":"Hall"}},
    {"@type":"Event","name":"Floating","startDate":"2026-11-23T09:00:00"}]}
    </script>
    """
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = try #require(TimeZone(secondsFromGMT: 0))
    let result = PlanImport.structuredEvents(source, calendar: utc)
    #expect(result.appointments.map(\.title) == ["Concert", "Floating"])
    #expect(result.appointments.first?.time == "10:00")
    #expect(result.appointments.first?.duration == 60)
    #expect(result.appointments.first?.location == "Hall")
    #expect(result.appointments.last?.time == "")
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["FRI_VERIFY_PUBLIC_NETWORK"] == "1"))
func directPublicHTTPSConnectsUsingTheVerifiedHostname() async throws {
    let text = try await PublicCalendarSource.read("https://example.com/")
    #expect(text.contains("Example Domain"))
}

@Test func widgetPrioritizesActiveThenUpcomingAndCompletedState() throws {
    let day = try #require(CalendarClock.date("2026-11-23"))
    let now = try #require(CalendarClock.local.date(bySettingHour: 10, minute: 30, second: 0, of: day))
    var state = CalendarState()
    state.tasks = [task("Past", time: "08:00", duration: 30),
                   task("Upcoming", time: "11:00", duration: 30),
                   task("Active", time: "10:00", duration: 60)]
    let snapshot = WidgetSnapshot(state: state, day: day, now: now)
    #expect(snapshot.tasks.map(\.title) == ["Active", "Upcoming", "Past"])
    #expect(snapshot.total == 3 && snapshot.completed == 0)
    state.tasks = state.tasks.map { var item = $0; item.done = true; return item }
    let completed = WidgetSnapshot(state: state, day: day, now: now)
    #expect(completed.tasks.isEmpty && completed.completed == 3)
    #expect(WidgetSnapshot(state: CalendarState(), day: day, now: now).total == 0)
}

@Test func widgetTimelineContainsStartsEndsAndStaysBounded() throws {
    let day = try #require(CalendarClock.date("2026-11-23"))
    let now = try #require(CalendarClock.local.date(bySettingHour: 8, minute: 0, second: 0, of: day))
    var state = CalendarState()
    state.tasks = [task("Read", time: "09:00", duration: 60), task("Walk", time: "10:00", duration: 30)]
    let dates = WidgetSnapshot.refreshDates(state: state, day: day, now: now)
    #expect(dates.map { CalendarClock.local.component(.hour, from: $0) } == [8, 9, 10, 10])
    #expect(dates.count == Set(dates).count)
    let tomorrow = try #require(CalendarClock.local.date(byAdding: .day, value: 1, to: day))
    #expect(WidgetSnapshot.refreshDates(state: state, day: tomorrow, now: now) == [now])
    state.tasks = (0..<100).map { task("Task \($0)", time: CalendarClock.time(500 + $0 * 5), duration: 2) }
    #expect(WidgetSnapshot.refreshDates(state: state, day: day, now: now).count == 31)
    #expect(WidgetSnapshot(state: state, day: day, now: now).tasks.count == 5)
}

@Test func widgetServicesRespectOptOutAndCachedAge() throws {
    let day = try #require(CalendarClock.date("2026-11-23"))
    var state = CalendarState()
    state.settings["appleWeatherCache"] = .object(["summary": .string("Sunny"), "fetchedAt": .number(day.timeIntervalSince1970 - 3601)])
    #expect(WidgetSnapshot(state: state, day: day, now: day).service == "Sunny · cached")
    #expect(WidgetSnapshot(state: state, day: day, now: day, showServices: false).service == nil)
    state.settings["activity"] = .object(["date": .string("2026-11-23"), "steps": .number(3200)])
    #expect(WidgetSnapshot(state: state, day: day, now: day).service == "3200 steps")
}

@Test func undoRestoreReturnsTheEntireCalendarAndSettings() async throws {
    try await withStore { store, _ in
        var before = CalendarState()
        before.tasks = [task("Original", time: "09:00", duration: 30)]
        before.active = "2026-11-23"
        before.tabs = ["2026-11-23"]
        before.settings = ["large": .bool(true), "reminders": .bool(true)]
        before.widgets = [.object(["name": .string("Original widget")])]
        before.collections = [.string("Original collection")]
        before.finished = [.string("2026-11-22")]
        _ = try store.restore(before)
        var replacement = CalendarState()
        replacement.active = "2026-12-01"
        replacement.settings = ["large": .bool(false)]
        let restored = try store.restore(replacement)
        let undo = CalendarUndo.restore(before: restored.previous, after: restored.restored.state)
        try store.update { $0 = try undo.applying(to: $0) }
        #expect(try store.read().state == before)
    }
}

@Test func undoAppointmentsPreservesUnrelatedSettingsAndRejectsNewerCompletion() throws {
    var before = CalendarState()
    before.tasks = [task("Appointment", time: "10:00", duration: 30)]
    var after = before
    after.tasks[0].title = "Edited"
    let undo = CalendarUndo.appointments(before: before, after: after)
    var latest = after
    latest.settings["large"] = .bool(true)
    latest.active = "2026-12-01"
    let result = try undo.applying(to: latest)
    #expect(result.tasks == before.tasks)
    #expect(result.settings == latest.settings && result.active == latest.active)
    latest.tasks[0].done = true
    #expect(throws: CalendarError.self) { try undo.applying(to: latest) }
    latest = after
    latest.finished = [.string("2026-11-23")]
    #expect(throws: CalendarError.self) { try undo.applying(to: latest) }
    latest = after
    latest.settings["large"] = .bool(true)
    #expect(throws: CalendarError.self) {
        try CalendarUndo.restore(before: before, after: after).applying(to: latest)
    }
}

@Test func reminderLeadTimeCompletionAndMidnight() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 25_200))
    let day = try #require(CalendarClock.date("2026-11-23", calendar: calendar))
    let now = try #require(calendar.date(bySettingHour: 9, minute: 56, second: 0, of: day))
    var done = task("Already complete", time: "10:30", duration: 30)
    done.done = true
    let plans = ReminderPlan.upcoming([task("Imminent", time: "10:00", duration: 30),
                                     task("Later", time: "11:00", duration: 60),
                                     task("Past", time: "09:00", duration: 30), done], now: now, calendar: calendar)
    #expect(plans.count == 2)
    #expect(plans[0].firesAt == now.addingTimeInterval(1))
    #expect(plans[1].startsAt.timeIntervalSince(plans[1].firesAt) == 300)
    var midnight = task("Tomorrow", time: "00:02", duration: 30)
    midnight.date = "2026-11-24"
    let target = try #require(ReminderPlan.upcoming([midnight], now: now, calendar: calendar).first)
    #expect(CalendarClock.day(target.firesAt, calendar: calendar) == "2026-11-23")
    #expect(calendar.component(.hour, from: target.firesAt) == 23)
    #expect(calendar.component(.minute, from: target.firesAt) == 57)
}

@Test func reminderDoesNotShiftNonexistentDSTTimeToAnotherDay() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
    var missing = task("Skipped clock time", time: "02:30", duration: 30)
    missing.date = "2026-03-08"
    let now = try #require(CalendarClock.date("2026-03-07", calendar: calendar))
    #expect(ReminderPlan.upcoming([missing], now: now, calendar: calendar).isEmpty)
}

@Test func spotifyLinksUseSupportedPublicResources() {
    #expect(ServiceLinks.spotify("https://open.spotify.com/playlist/abc123?si=tracking")?.absoluteString == "https://open.spotify.com/playlist/abc123")
    #expect(ServiceLinks.spotify("https://open.spotify.com/artist/abc123") == nil)
    #expect(ServiceLinks.spotify("https://open.spotify.com.evil.example/track/abc") == nil)
    #expect(ServiceLinks.spotify("https://user@open.spotify.com/track/abc") == nil)
    #expect(ServiceLinks.spotify("http://open.spotify.com/track/abc") == nil)
}
