import CryptoKit
import FRICore
import SwiftUI
import UserNotifications
import WidgetKit

@main
struct FRIApp: App {
    @State private var calendar = FRICalendarSession()

    var body: some Scene {
        WindowGroup("FRI") {
            FRIWorkspaceView(calendar: calendar)
                #if os(macOS)
                .frame(minWidth: 540, minHeight: 520)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1050, height: 740)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Schedule") { calendar.newDraft(deadline: false) }
                    .keyboardShortcut("n")
                Button("New Deadline") { calendar.newDraft(deadline: true) }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Divider()
                Button("Import Plans…") { calendar.panel = .importPlans }
                Button("Export Backup…") { calendar.fileAction = .exportBackup }
                Button("Restore Backup…") { calendar.fileAction = .restoreBackup }
                Button("Add FRI Widget…") { calendar.panel = .widget }
            }
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") { calendar.undo() }.keyboardShortcut("z").disabled(!calendar.canUndo)
            }
            CommandMenu("View") {
                Button("Today") { calendar.select(CalendarClock.day()) }.keyboardShortcut("1")
                Button("Month") { calendar.view = .month }.keyboardShortcut("2")
                Button("Year") { calendar.view = .year }.keyboardShortcut("3")
                Button("Search") { calendar.panel = .search }.keyboardShortcut("f")
            }
        }
        #endif
    }
}

@MainActor
@Observable
final class FRICalendarSession {
    enum CalendarView: String, CaseIterable { case day = "Day", month = "Month", year = "Year" }
    enum Panel: String, Identifiable {
        case draft, search, manage, importPlans, widget, appearance, services, planner, availability
        var id: String { rawValue }
    }
    enum FileAction { case exportBackup, restoreBackup, exportAvailability, compareAvailability }

    private(set) var state = CalendarState()
    private(set) var ready = false
    private(set) var synthetic = false
    private var store: CalendarStore?
    private var observedWrite: Date?
    private var undoState: (before: CalendarState, after: CalendarState)?
    private var lastReminderTasks: [Appointment]?
    var canUndo: Bool { undoState != nil }
    var message: String?
    var panel: Panel?
    var fileAction: FileAction?
    var view: CalendarView = .day
    var cursor: Date = .now
    var appointment: Appointment?
    var draftDeadline = false
    var onlyPending = false
    var restoreCandidate: CalendarState?
    var matchResults: [DateInterval]?

    func open() {
        do {
            if store == nil {
                #if DEBUG
                if ProcessInfo.processInfo.environment["FRI_SYNTHETIC_PREVIEW"] == "1" {
                    synthetic = true
                    let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                    store = CalendarStore(directory: root.appending(path: "FRI-Synthetic")) { _ in
                        // Fixed fixture key for Debug smoke runs with synthetic data only.
                        CryptoKit.SymmetricKey(data: Data(repeating: 0x46, count: 32))
                    }
                } else {
                    store = try CalendarStore.shared()
                }
                #else
                store = try CalendarStore.shared()
                #endif
            }
            guard let store else { throw CalendarError.unavailableStore }
            let stamp = store.modificationDate
            let loaded = try store.read()
            observedWrite = stamp
            if !ready {
                cursor = CalendarClock.date(loaded.state.active) ?? .now
            }
            if loaded.state != state || !ready {
                state = loaded.state
                reconcileReminders()
            }
            ready = true
        } catch {
            ready = false
            message = error.localizedDescription
        }
    }

    func refreshIfChanged() {
        if store?.modificationDate != observedWrite { open() }
    }

    func newDraft(deadline: Bool) {
        guard ready else { return }
        draftDeadline = deadline
        panel = .draft
    }

    func select(_ day: String) {
        guard let date = CalendarClock.date(day) else { return }
        guard change({ state in
            state.active = day
            if !state.tabs.contains(day) { state.tabs.append(day) }
        }) else { return }
        cursor = date
        view = .day
    }

    func closeTab(_ day: String) {
        _ = change { state in
            state.tabs.removeAll { $0 == day }
            if state.active == day { state.active = state.tabs.last ?? CalendarClock.day() }
        }
        cursor = CalendarClock.date(state.active) ?? .now
    }

    @discardableResult
    func change(undoable: Bool = false, _ update: (inout CalendarState) throws -> Void) -> Bool {
        do {
            guard let store else { throw CalendarError.unavailableStore }
            var previous = state
            let current = try store.update { latest in
                previous = latest
                try update(&latest)
            }
            state = current.state
            if previous.tasks != state.tasks || previous.drafts != state.drafts {
                undoState = undoable ? (previous, state) : nil
            }
            WidgetCenter.shared.reloadTimelines(ofKind: "FRIDayWidget")
            reconcileReminders()
            return true
        } catch {
            message = error.localizedDescription
            return false
        }
    }

    func undo() {
        guard let undo = undoState else { return }
        _ = change { latest in
            guard latest.tasks == undo.after.tasks, latest.drafts == undo.after.drafts else {
                throw FRISessionError.changedSinceUndo
            }
            latest.tasks = undo.before.tasks
            latest.drafts = undo.before.drafts
            latest.finished = undo.before.finished
        }
        undoState = nil
    }

    func addDrafts(_ drafts: [Appointment]) -> Bool {
        change { state in
            for draft in drafts {
                if let key = draft.sourceKey, !key.isEmpty,
                   (state.tasks + state.drafts).contains(where: { $0.sourceKey == key }) { continue }
                if let index = state.drafts.firstIndex(where: { $0.id == draft.id }) {
                    state.drafts[index] = draft
                } else {
                    state.drafts.append(draft)
                }
            }
        }
    }

    func save(_ plans: [Appointment], editing base: Appointment? = nil, allowOverlap: Bool = false) -> Bool {
        change(undoable: true) { state in
            for incoming in plans {
                var item = incoming
                var targetIndex: Int?
                if let base {
                    guard let index = state.tasks.firstIndex(where: { $0.id == base.id }) else { throw CalendarError.missingAppointment }
                    targetIndex = index
                    let current = state.tasks[index]
                    if item.title == base.title { item.title = current.title }
                    if item.date == base.date { item.date = current.date }
                    if item.time == base.time { item.time = current.time }
                    if item.duration == base.duration { item.duration = current.duration }
                    if item.kind == base.kind { item.kind = current.kind }
                    if item.category == base.category { item.category = current.category }
                    if item.location == base.location { item.location = current.location }
                    if item.notes == base.notes { item.notes = current.notes }
                    item.done = current.done
                    item.sourceKey = current.sourceKey
                }
                try item.validate()
                if !item.isDeadline, item.duration == 0 { throw CalendarError.invalidAppointment }
                if !allowOverlap, let overlap = item.conflict(in: state.tasks) { throw CalendarError.overlap(overlap.title) }
                if let targetIndex { state.tasks[targetIndex] = item }
                else if !state.tasks.contains(where: { $0.id == item.id }) { state.tasks.append(item) }
                state.finished.removeAll { $0.string == item.date || $0.string == base?.date }
                state.drafts.removeAll { $0.id == item.id }
            }
        }
    }

    func setDoneWithoutOpening(_ item: Appointment) {
        setDone(item, showDetails: false)
    }

    func setDone(_ item: Appointment, showDetails: Bool = true) {
        if change(undoable: true, { latest in
            guard let index = latest.tasks.firstIndex(where: { $0.id == item.id }) else { throw CalendarError.missingAppointment }
            latest.tasks[index].done = !item.done
            if item.done { latest.finished.removeAll { $0.string == item.date } }
        }), showDetails {
            appointment = state.tasks.first { $0.id == item.id }
        }
    }

    func remove(_ ids: Set<String>) {
        if change(undoable: true, { state in
            let days = Set(state.tasks.filter { ids.contains($0.id) }.map(\.date))
            state.tasks.removeAll { ids.contains($0.id) }
            state.finished.removeAll { $0.string.map(days.contains) ?? false }
        }) {
            appointment = nil
        }
    }

    func updateSetting(_ key: String, _ value: JSONValue?) {
        _ = change { $0.settings[key] = value }
    }

    func restore() {
        guard let backup = restoreCandidate, let store else { return }
        do {
            let result = try store.restore(backup)
            state = result.restored.state
            undoState = (result.previous, state)
            cursor = CalendarClock.date(state.active) ?? .now
            WidgetCenter.shared.reloadTimelines(ofKind: "FRIDayWidget")
            reconcileReminders()
        } catch {
            message = error.localizedDescription
        }
        restoreCandidate = nil
    }

    func openURL(_ url: URL) {
        guard url.scheme == "fri", url.user == nil, url.password == nil,
              url.port == nil, url.query == nil, url.fragment == nil else { message = "This FRI link is invalid."; return }
        let parts = url.pathComponents.dropFirst()
        guard parts.count == 1, let value = parts.first else { message = "This FRI link is invalid."; return }
        switch url.host {
        case "day":
            guard CalendarClock.date(value) != nil else { message = "This calendar date is invalid."; return }
            select(value)
        case "task":
            guard let task = state.tasks.first(where: { $0.id == value }) else {
                message = CalendarError.missingAppointment.localizedDescription
                return
            }
            select(task.date)
            appointment = task
        default: message = "This FRI link is invalid."
        }
    }

    func setReminders(_ enabled: Bool) async {
        if enabled {
            do {
                guard try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) else {
                    message = "Notifications are disabled in system settings."
                    return
                }
            } catch {
                message = error.localizedDescription
                return
            }
        }
        lastReminderTasks = nil
        updateSetting("reminders", .bool(enabled))
    }

    private var reminderUpdate: Task<Void, Never>?

    private func reconcileReminders() {
        let tasks = state.settings["reminders"]?.bool == true ? state.tasks : []
        guard tasks != lastReminderTasks else { return }
        lastReminderTasks = tasks
        let previous = reminderUpdate
        reminderUpdate = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            await FRIAppointmentsNotification.reconcile(tasks)
        }
        previous?.cancel()
    }
}

private enum FRISessionError: LocalizedError {
    case changedSinceUndo
    var errorDescription: String? { "The calendar changed. Undo would replace newer edits." }
}

private enum FRIAppointmentsNotification {
    static func reconcile(_ tasks: [Appointment]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix("fri.appointment.") })
        let calendar = CalendarClock.local
        let upcoming = tasks.compactMap { item -> (Appointment, Date)? in
            guard !item.done, let minute = CalendarClock.minutes(item.time),
                  let day = CalendarClock.date(item.date),
                  let instant = calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day),
                  instant > .now else { return nil }
            return (item, instant)
        }.sorted { $0.1 < $1.1 }
        for (item, instant) in upcoming.prefix(48) {
            guard !Task.isCancelled else { return }
            let content = UNMutableNotificationContent()
            content.title = "FRI reminder"
            content.body = "You have an appointment now."
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: instant), repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "fri.appointment.\(item.id)", content: content, trigger: trigger))
        }
    }
}
