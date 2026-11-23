import CryptoKit
import Foundation

/// Compiled with the real FRICore sources by verify-backup-interop.cjs.
/// All files and encryption keys are disposable fixtures, never a user's store.
@main
struct BackupInterop {
    static func main() {
        do { try run() }
        catch {
            FileHandle.standardError.write(Data("Backup rejected: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }

    private static func run() throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 3 else { throw CalendarError.invalidBackup }
        let source = try Data(contentsOf: URL(fileURLWithPath: arguments[1]))
        let imported = try CalendarBackup.read(source)
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let key = SymmetricKey(size: .bits256)
        let store = CalendarStore(directory: directory) { _ in key }
        _ = try store.restore(imported)
        let reopened = CalendarStore(directory: directory) { _ in key }
        guard try reopened.read().state == imported else { throw CalendarError.damagedStore }
        try reopened.update { state in
            var native = Appointment()
            native.id = "native-roundtrip"
            native.title = "Lịch từ Swift — ☕️"
            native.date = "2026-11-24"
            native.time = "16:10"
            native.duration = 45
            native.kind = "schedule"
            native.location = "Phòng họp"
            native.notes = "Line one\nLine two, with a comma"
            state.tasks.append(native)
        }
        try CalendarBackup.export(reopened.read().state)
            .write(to: URL(fileURLWithPath: arguments[2]), options: .atomic)
    }
}
