import CryptoKit
import Foundation

/// Local scheduling receipts, independent of Notification Center's dismissible list.
/// These record OS acceptance, not proof that a person saw an alert.
public struct ReminderReceipts: Codable, Sendable {
    private struct Receipt: Codable, Sendable {
        let startsAt: Date
        let firesAt: Date
    }
    private var receipts: [String: Receipt] = [:]

    public init() {}

    public mutating func record(_ plan: ReminderPlan, firesAt: Date) {
        receipts[Self.key(plan.identifier)] = Receipt(startsAt: plan.startsAt, firesAt: firesAt)
    }

    public func hasElapsed(_ plan: ReminderPlan, now: Date = .now) -> Bool {
        guard let receipt = receipts[Self.key(plan.identifier)] else { return false }
        return receipt.startsAt == plan.startsAt && receipt.firesAt <= now
    }

    /// Forget canceled future requests, but retain elapsed ones until appointment start.
    /// Disabling/re-enabling or completing/undoing must not replay an elapsed reminder.
    public mutating func retain(_ plans: [ReminderPlan], now: Date = .now) {
        let wanted = Dictionary(plans.map { (Self.key($0.identifier), $0.startsAt) }, uniquingKeysWith: { first, _ in first })
        receipts = receipts.filter { key, receipt in
            receipt.startsAt > now && (receipt.firesAt <= now || wanted[key] == receipt.startsAt)
        }
    }

    private static func key(_ identifier: String) -> String {
        SHA256.hash(data: Data(identifier.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
