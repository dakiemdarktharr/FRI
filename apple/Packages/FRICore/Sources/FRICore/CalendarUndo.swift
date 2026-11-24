import Foundation

/// Undo protects edits made by another window or widget after the original action.
public enum CalendarUndo: Sendable {
    case appointments(before: CalendarState, after: CalendarState)
    case restore(before: CalendarState, after: CalendarState)

    public func applying(to latest: CalendarState) throws -> CalendarState {
        switch self {
        case let .appointments(before, after):
            guard latest.tasks == after.tasks, latest.drafts == after.drafts,
                  latest.finished == after.finished else { throw CalendarError.changedSinceUndo }
            var result = latest
            result.tasks = before.tasks
            result.drafts = before.drafts
            result.finished = before.finished
            return result
        case let .restore(before, after):
            guard latest == after else { throw CalendarError.changedSinceUndo }
            return before
        }
    }
}
