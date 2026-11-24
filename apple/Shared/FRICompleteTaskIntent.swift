import AppIntents
import FRICore
import UserNotifications

struct FRICompleteTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete FRI appointment"

    @Parameter(title: "Appointment") var taskID: String

    init() {}
    init(taskID: String) { self.taskID = taskID }

    func perform() async throws -> some IntentResult {
        try CalendarStore.shared().complete(taskID)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["fri.appointment.\(taskID)"])
        center.removeDeliveredNotifications(withIdentifiers: ["fri.appointment.\(taskID)"])
        return .result()
    }
}
