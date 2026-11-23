import CryptoKit
import FRICore
import SwiftUI
import UserNotifications
import WidgetKit

@main
struct FRIApp: App {
    @State private var calendar = FRICalendarSession()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup("FRI", id: "calendar") {
            FRIWorkspaceView(calendar: calendar)
                #if os(macOS)
                .frame(minWidth: 540, minHeight: 520)
                #endif
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            #if os(iOS)
            calendar.setPeriodicUpdatesEnabled(phase == .active)
            #else
            // AppKit panels remain useful when the main calendar is not frontmost.
            if phase == .active { calendar.setPeriodicUpdatesEnabled(true) }
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
                Button("Import Plans…") { calendar.show(.importPlans) }
                Button("Export Backup…") { calendar.requestFile(.exportBackup) }
                Button("Restore Backup…") { calendar.requestFile(.restoreBackup) }
                Button("New Desktop Widget") { calendar.addDesktopWidget() }
                Button("Show Desktop Widgets") { calendar.showDesktopWidgets() }
                Button("Widget Gallery…") { calendar.show(.widget) }
            }
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") { calendar.undo() }.keyboardShortcut("z").disabled(!calendar.canUndo)
            }
            CommandGroup(after: .sidebar) {
                Button("Today") { calendar.revealCalendar?(); calendar.select(CalendarClock.day()) }.keyboardShortcut("1")
                Button("Month") { calendar.revealCalendar?(); calendar.view = .month }.keyboardShortcut("2")
                Button("Year") { calendar.revealCalendar?(); calendar.view = .year }.keyboardShortcut("3")
                Button("Search") { calendar.show(.search) }.keyboardShortcut("f")
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
        case draft, search, manage, importPlans, widget, appearance, services, planner, availability, dayAssistant, collections
        var id: String { rawValue }
    }
    enum FileAction { case exportBackup, restoreBackup, exportAvailability, compareAvailability }

    private(set) var state = CalendarState()
    private(set) var ready = false
    private(set) var opening = false
    private var pendingOpenURL: URL?
    private(set) var synthetic = false
    private var store: CalendarStore?
    @ObservationIgnored let spotifyPlayer = FRISpotifyPlayer()
    @ObservationIgnored private let automaticWeather = WeatherAutoRefresh()
    @ObservationIgnored private var periodicUpdates: Task<Void, Never>?
    @ObservationIgnored private var weatherUpdatesEnabled = false
    #if os(macOS)
    @ObservationIgnored var revealCalendar: (() -> Void)?
    @ObservationIgnored private var desktopWidgets: FRIDesktopWidgetManager?
    func addDesktopWidget() {
        guard ready else { return }
        desktopWidgets?.add()
    }
    func showDesktopWidgets() { desktopWidgets?.showAll() }
    #endif
    private var observedWrite: Date?
    private var undoState: CalendarUndo?
    private var reminderSchedule = ReminderSchedule()
    var canUndo: Bool { undoState != nil }
    var message: String?
    var panel: Panel?
    var fileAction: FileAction?
    var view: CalendarView = .day
    var cursor: Date = .now
    var appointment: Appointment?
    var draftDeadline = false
    var draftReviewIDs: Set<String>?
    var draftStartingID: String?
    var dayHistory: [FRIDayMessage] = [.greeting]
    var onlyPending = false
    var collection: String?
    var restoreCandidate: CalendarState?
    var matchResults: [DateInterval]?

    func open() {
        guard !opening else { return }
        do {
            if store == nil {
                #if DEBUG
                if ProcessInfo.processInfo.environment["FRI_SYNTHETIC_PREVIEW"] == "1" {
                    synthetic = true
                    let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                    let testID = ProcessInfo.processInfo.environment["FRI_TEST_STORE_ID"].flatMap(UUID.init(uuidString:))
                    let directory = testID.map { "FRI-Tests/\($0.uuidString)" } ?? "FRI-Synthetic"
                    store = CalendarStore(directory: root.appending(path: directory)) { _ in
                        // Fixed fixture key for Debug smoke runs with synthetic data only.
                        CryptoKit.SymmetricKey(data: Data(repeating: 0x46, count: 32))
                    }
                } else {
                    store = try configuredStore()
                }
                #else
                store = try configuredStore()
                #endif
            }
            guard let store else { throw CalendarError.unavailableStore }
            if !ready {
                opening = true
                message = nil
                Task {
                    defer { opening = false }
                    do {
                        let result = try await Task.detached {
                            let stamp = store.modificationDate
                            return (try store.prepare(), stamp)
                        }.value
                        accept(result.0, stamp: result.1)
                    } catch {
                        ready = false
                        message = error.localizedDescription
                    }
                }
            } else {
                let stamp = store.modificationDate
                accept(try store.read(), stamp: stamp)
            }
        } catch {
            ready = false
            message = error.localizedDescription
        }
    }

    private func accept(_ loaded: CalendarRevision, stamp: Date?) {
        observedWrite = stamp
        if !ready { cursor = CalendarClock.date(loaded.state.active) ?? .now }
        if loaded.state != state || !ready {
            state = loaded.state
        }
        spotifyPlayer.largeText = state.settings["large"]?.bool == true
        if let playing = spotifyPlayer.resourceURL,
           state.settings["spotifyUrl"]?.string.flatMap(ServiceLinks.spotify) != playing {
            spotifyPlayer.close()
        }
        ready = true
        reconcileReminders()
        refreshWeatherAutomatically()
        #if os(macOS)
        if desktopWidgets == nil { desktopWidgets = FRIDesktopWidgetManager(calendar: self) }
        #endif
        if let pending = pendingOpenURL {
            pendingOpenURL = nil
            openURL(pending)
        }
    }

    private func configuredStore() throws -> CalendarStore {
        #if os(macOS)
        if Bundle.main.object(forInfoDictionaryKey: "FRIStorageMode") as? String == "standalone" {
            return try CalendarStore.standaloneMac()
        }
        #endif
        return try CalendarStore.shared()
    }

    func refreshIfChanged() {
        if store?.modificationDate != observedWrite { open() }
    }

    func setPeriodicUpdatesEnabled(_ enabled: Bool) {
        weatherUpdatesEnabled = enabled
        if !enabled {
            periodicUpdates?.cancel()
            periodicUpdates = nil
            automaticWeather.cancel()
            return
        }
        reconcileReminders()
        refreshWeatherAutomatically()
        guard periodicUpdates == nil else { return }
        periodicUpdates = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
                guard let self, !Task.isCancelled else { return }
                self.refreshIfChanged()
                self.reconcileReminders()
                self.refreshWeatherAutomatically()
            }
        }
    }

    func cancelAutomaticWeather() { automaticWeather.cancel() }

    private func refreshWeatherAutomatically() {
        guard weatherUpdatesEnabled, ready, panel != .services else { return }
        automaticWeather.refreshIfNeeded(settings: state.settings) { [weak self] forecast, expected in
            guard let self, let store = self.store, self.ready else { return }
            var previous = self.state
            let current = try store.update {
                previous = $0
                try $0.applyWeather(forecast, replacing: expected)
            }
            // A background cache update must not make a just-restored backup impossible to undo.
            if case let .restore(before, after) = self.undoState, after == previous {
                self.undoState = .restore(before: before, after: current.state)
            }
            self.accept(current, stamp: store.modificationDate)
            WidgetCenter.shared.reloadTimelines(ofKind: "FRIDayWidget")
        }
    }

    func newDraft(deadline: Bool, startingID: String? = nil) {
        guard ready else { return }
        draftReviewIDs = nil
        draftStartingID = startingID
        draftDeadline = deadline
        show(.draft)
    }

    func reviewDrafts(_ ids: Set<String>) {
        guard ready, !ids.isEmpty else { return }
        draftStartingID = nil
        draftReviewIDs = ids
        show(.draft)
    }

    func show(_ destination: Panel) {
        guard ready else { return }
        #if os(macOS)
        revealCalendar?()
        #endif
        panel = destination
    }

    func requestFile(_ action: FileAction) {
        guard ready else { return }
        #if os(macOS)
        revealCalendar?()
        #endif
        fileAction = action
    }

    func select(_ day: String) {
        guard let date = CalendarClock.date(day) else { return }
        guard change({ state in
            state.active = day
            if !state.tabs.contains(day) { state.tabs.append(day) }
        }) else { return }
        cursor = date
        view = .day
        collection = nil
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
                undoState = undoable ? .appointments(before: previous, after: state) : nil
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
        if change({ latest in latest = try undo.applying(to: latest) }) {
            undoState = nil
            cursor = CalendarClock.date(state.active) ?? .now
            appointment = appointment.flatMap { selected in state.tasks.first { $0.id == selected.id } }
        }
    }

    func addDrafts(_ drafts: [Appointment]) -> Bool {
        change { $0.stageDrafts(drafts) }
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
            undoState = .restore(before: result.previous, after: state)
            cursor = CalendarClock.date(state.active) ?? .now
            WidgetCenter.shared.reloadTimelines(ofKind: "FRIDayWidget")
            reconcileReminders()
        } catch {
            message = error.localizedDescription
        }
        restoreCandidate = nil
    }

    func openURL(_ url: URL) {
        guard ready else { pendingOpenURL = url; return }
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
        updateSetting("reminders", .bool(enabled))
        reconcileReminders(force: true)
    }

    private var reminderUpdate: Task<Void, Never>?

    private func reconcileReminders(force: Bool = false) {
        guard ready else { return }
        let tasks = state.settings["reminders"]?.bool == true ? state.tasks : []
        guard let plans = reminderSchedule.update(for: tasks, force: force) else { return }
        let previous = reminderUpdate
        reminderUpdate = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            let failure = await FRIAppointmentsNotification.reconcile(plans)
            if !Task.isCancelled, let failure {
                reminderSchedule.retryAfterFailure()
                message = failure
            }
        }
        previous?.cancel()
    }
}

private enum FRIAppointmentsNotification {
    static func reconcile(_ plans: [ReminderPlan]) async -> String? {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let delivered = await center.deliveredNotifications()
        guard !Task.isCancelled else { return nil }
        let wanted = Set(plans.map(\.identifier))
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter {
            $0.hasPrefix("fri.appointment.") && !wanted.contains($0)
        })
        center.removeDeliveredNotifications(withIdentifiers: delivered.map { $0.request.identifier }.filter {
            $0.hasPrefix("fri.appointment.") && !wanted.contains($0)
        })
        for plan in plans {
            guard !Task.isCancelled else { return nil }
            guard plan.startsAt > .now else { continue }
            let existing = pending.first { $0.identifier == plan.identifier }
                ?? delivered.first { $0.request.identifier == plan.identifier }?.request
            if let stamp = existing?.content.userInfo["appointmentStart"] as? Double,
               stamp == plan.startsAt.timeIntervalSince1970 { continue }
            let content = UNMutableNotificationContent()
            content.title = "FRI · Coming up"
            content.body = "You have an appointment soon. Open FRI to view it."
            content.sound = .default
            content.userInfo = ["appointmentStart": plan.startsAt.timeIntervalSince1970]
            let fireDate = max(plan.firesAt, Date.now.addingTimeInterval(1))
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: CalendarClock.local.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate),
                repeats: false
            )
            do { try await center.add(UNNotificationRequest(identifier: plan.identifier, content: content, trigger: trigger)) }
            catch { return "FRI could not schedule reminders. Check notification access in system settings and try again." }
        }
        return nil
    }
}
