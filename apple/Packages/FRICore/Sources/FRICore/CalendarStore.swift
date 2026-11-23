import CryptoKit
import Darwin
import Foundation
import Security

public struct CalendarRevision: Codable, Sendable {
    public var state: CalendarState = .init()
    public var revision = 0
}

public struct CalendarStore: Sendable {
    private let directory: URL
    private let keySource: @Sendable (Bool) throws -> SymmetricKey
    private var file: URL { directory.appending(path: "calendar.v1.aesgcm") }

    public init(directory: URL, keySource: @escaping @Sendable (_ mayCreate: Bool) throws -> SymmetricKey) {
        self.directory = directory
        self.keySource = keySource
    }

    public static func shared(bundle: Bundle = .main) throws -> Self {
        guard let group = bundle.object(forInfoDictionaryKey: "FRIAppGroup") as? String,
              let keychain = bundle.object(forInfoDictionaryKey: "FRIKeychainGroup") as? String,
              !keychain.isEmpty, !keychain.hasPrefix("."),
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
        else { throw CalendarError.unavailableStore }
        let cache = CalendarKeyCache()
        return Self(directory: container.appending(path: "Calendar")) { mayCreate in
            try cache.resolve { try keychainKey(group: keychain, mayCreate: mayCreate) }
        }
    }

    #if os(macOS)
    /// Explicit standalone Mac storage. It is never a fallback for a failed shared store.
    /// Native desktop panels share the host session; WidgetKit continues to use shared().
    public static func standaloneMac(bundle: Bundle = .main) throws -> Self {
        guard let identifier = bundle.bundleIdentifier, !identifier.isEmpty else { throw CalendarError.unavailableStore }
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
        let cache = CalendarKeyCache()
        return Self(directory: root.appending(path: identifier).appending(path: "Calendar")) { mayCreate in
            try cache.resolve { try keychainKey(group: nil, mayCreate: mayCreate) }
        }
    }
    #endif

    private static func keychainKey(group: String?, mayCreate: Bool) throws -> SymmetricKey {
        var identity: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: group == nil ? "FRI.Calendar.Standalone" : "FRI.Calendar",
            kSecAttrAccount as String: "v1"
        ]
        if let group {
            identity[kSecAttrAccessGroup as String] = group
            identity[kSecUseDataProtectionKeychain as String] = true
        }
        // The standalone Mac distribution uses the login keychain and its application ACL.
        // No App Group, shared-access entitlement, or synthetic key is used for this mode.
        var query = identity
        query[kSecReturnData as String] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data, data.count == 32 {
            return SymmetricKey(data: data)
        }
        guard status == errSecItemNotFound, mayCreate else { throw CalendarError.unavailableStore }
        let key = SymmetricKey(size: .bits256)
        var attributes = identity
        attributes[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
        if group != nil { attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly }
        guard SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess else {
            throw CalendarError.unavailableStore
        }
        return key
    }

    public var modificationDate: Date? {
        try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    /// Call off the UI thread: the OS may ask the user to unlock or authorize Keychain access.
    public func prepare() throws -> CalendarRevision {
        try locked {
            let existing = try readLocked()
            if existing.revision == 0 { _ = try keySource(true) }
            return existing
        }
    }

    public func read() throws -> CalendarRevision {
        try locked { try readLocked() }
    }

    @discardableResult
    public func update(_ changes: (inout CalendarState) throws -> Void) throws -> CalendarRevision {
        try locked {
            let existing = try readLocked()
            var next = existing
            try changes(&next.state)
            if next.state == existing.state { return existing }
            try next.state.validate()
            next.revision += 1
            try write(next, to: file, mayCreate: existing.revision == 0)
            return next
        }
    }

    public func restore(_ replacement: CalendarState) throws -> (previous: CalendarState, restored: CalendarRevision) {
        try locked {
            let existing = try readLocked()
            try replacement.validate()
            if existing.state == replacement { return (existing.state, existing) }
            if existing.revision > 0 {
                try write(existing, to: directory.appending(path: "pre-restore.v1.aesgcm"), mayCreate: false)
            }
            let next = CalendarRevision(state: replacement, revision: existing.revision + 1)
            try write(next, to: file, mayCreate: existing.revision == 0)
            return (existing.state, next)
        }
    }

    @discardableResult
    public func complete(_ id: String) throws -> CalendarRevision {
        try update { state in
            guard let index = state.tasks.firstIndex(where: { $0.id == id }) else { throw CalendarError.missingAppointment }
            state.tasks[index].done = true
        }
    }

    private func write(_ version: CalendarRevision, to url: URL, mayCreate: Bool) throws {
        let payload = try JSONEncoder().encode(version)
        let key = try keySource(mayCreate)
        let box = try AES.GCM.seal(payload, using: key, authenticating: Data("FRI.Calendar.v1".utf8))
        guard let encrypted = box.combined else { throw CalendarError.unavailableStore }
        #if os(iOS)
        try encrypted.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try encrypted.write(to: url, options: .atomic)
        #endif
    }

    private func readLocked() throws -> CalendarRevision {
        let encrypted: Data
        do {
            let handle = try FileHandle(forReadingFrom: file)
            defer { try? handle.close() }
            encrypted = try handle.read(upToCount: CalendarBackup.sizeLimit + 1024) ?? Data()
        } catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile {
            return CalendarRevision()
        }
        let key = try keySource(false)
        do {
            let box = try AES.GCM.SealedBox(combined: encrypted)
            let payload = try AES.GCM.open(box, using: key, authenticating: Data("FRI.Calendar.v1".utf8))
            let result = try JSONDecoder().decode(CalendarRevision.self, from: payload)
            guard result.revision > 0 else { throw CalendarError.damagedStore }
            try result.state.validate()
            return result
        } catch {
            throw CalendarError.damagedStore
        }
    }

    private func locked<T>(_ body: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let path = directory.appending(path: "calendar.lock").path
        let descriptor = Darwin.open(path, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, mode_t(0o600))
        guard descriptor >= 0 else { throw CalendarError.unavailableStore }
        defer { Darwin.close(descriptor) }
        while flock(descriptor, LOCK_EX) != 0 {
            guard errno == EINTR else { throw CalendarError.unavailableStore }
        }
        defer { flock(descriptor, LOCK_UN) }
        return try body()
    }
}

/// A key lives only for this store instance's process lifetime; it is never written outside Keychain.
private final class CalendarKeyCache: @unchecked Sendable {
    private let lock = NSLock()
    private var key: SymmetricKey?

    func resolve(_ load: () throws -> SymmetricKey) throws -> SymmetricKey {
        lock.lock()
        defer { lock.unlock() }
        if let key { return key }
        let loaded = try load()
        key = loaded
        return loaded
    }
}
