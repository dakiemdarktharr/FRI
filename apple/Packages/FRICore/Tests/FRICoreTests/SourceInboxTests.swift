import Foundation
import Testing
@testable import FRICore

@Test func refreshPersistsSourcesAndReservesFixedPlansBeforeAssignmentWork() throws {
    let planner = try SourcePlanner()
    let now = try #require(CalendarClock.date("2030-06-05"))
    var state = CalendarState()
    let assignment = try planner.read(#"[{"title":"Essay","kind":"task","dueDate":"2030-06-06","dueTime":"11:00","effortMinutes":60,"leadDays":1}]"#)
    let fixed = try planner.read("title,kind,date,time,duration\nClass,schedule,2030-06-06,09:00,60\nClash,schedule,2030-06-06,09:30,15\nPast,schedule,2020-01-01,09:30,10", name: "plans.csv")
    try state.stageSource(PreparedSource(label: "Assignments", rows: assignment.rows))
    try state.stageSource(PreparedSource(label: "Classes", rows: fixed.rows))
    state = try CalendarBackup.read(CalendarBackup.export(state))
    #expect(state.tasks.isEmpty)
    #expect(state.importQueue.count == 2)
    let result = try planner.refresh(&state, now: now)
    #expect(result.added == 3 && result.held == 1 && result.skipped == 1)
    #expect(state.sourceLibrary.count == 2)
    #expect(state.tasks.first { $0.title == "Class" }?.time == "09:00")
    #expect(state.tasks.contains { $0.assignmentKey != nil })
    #expect(state.importQueue.first?.rows.first?["title"] == .string("Clash"))
    let retry = try planner.refresh(&state, now: now)
    #expect(retry.added == 0 && retry.held == 1)
    state.importQueue[0].rows[0]["time"] = .string("16:00")
    #expect(try planner.refresh(&state, now: now).added == 1)
    try state.stageSource(PreparedSource(label: "Classes again", rows: fixed.rows))
    #expect(try planner.refresh(&state, now: now).skipped >= 2)
}

@Test func calendarReaderAndQuestionsUseDesktopSemantics() throws {
    let planner = try SourcePlanner()
    let date = try #require(CalendarClock.local.date(byAdding: .day, value: 5, to: .now))
    let stamp = CalendarClock.day(date).replacingOccurrences(of: "-", with: "")
    let result = try planner.read("""
    BEGIN:VCALENDAR
    VERSION:2.0
    BEGIN:VEVENT
    UID:fri-recurrence
    DTSTART:\(stamp)T090000
    DTEND:\(stamp)T093000
    RRULE:FREQ=DAILY;COUNT=3
    SUMMARY:Vật lý
    END:VEVENT
    END:VCALENDAR
    """, name: "course.ics")
    #expect(result.rows.count == 3)
    #expect(result.rows.allSatisfy { $0["title"] == .string("Vật lý") })
    let missing = try #require(planner.read("Read chapter 09:15").rows.first)
    #expect(try planner.question(missing)?.first == "date")
}

@Test func docxReaderExtractsCalendarTextAndPastRecordsStayOut() throws {
    let document = try #require(Data(base64Encoded: "UEsDBBQAAAAIACSzeF3rp3bIfgAAAKAAAAARAAAAd29yZC9kb2N1bWVudC54bWw1zkEKwyAUBNCrSPapP2kTqFgXvYkYawS/X9Rie/vGQDcPhpnFyCY2Mm+0sbIPhlhEewx7rUlwXsxuUZcLJRuP7kUZdT1idrxR3lImY0vx0WHgM8DKUfs4KNlE6uROVU9PgdyXzXCdRljHaWFwFwDstjD0UfI+6ubTdPr/pH5QSwECFAMUAAAACAAks3hd66d2yH4AAACgAAAAEQAAAAAAAAAAAAAAgAEAAAAAd29yZC9kb2N1bWVudC54bWxQSwUGAAAAAAEAAQA/AAAArQAAAAAA"))
    let planner = try SourcePlanner()
    let text = try planner.documentText(document)
    #expect(text.contains("Biology"))
    let row = try #require(planner.read(text, name: "course.docx").rows.first)
    #expect(try planner.question(row) == nil)
    #expect(try !planner.past(row, now: #require(CalendarClock.date("2031-06-14"))))
    #expect(try planner.past(row, now: #require(CalendarClock.date("2031-06-16"))))
}
