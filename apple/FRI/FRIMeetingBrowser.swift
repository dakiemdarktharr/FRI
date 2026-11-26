#if os(macOS)
import AppKit
import Carbon
import CryptoKit

/// A durable grant identifies a browser and a chat service, never a tab URL.
struct MeetingWebSource: Hashable, Codable, Sendable {
    enum Service: String, Codable { case zalo = "Zalo", messenger = "Messenger" }
    let browser: String
    let service: Service

    init?(browser: String, service: Service) {
        guard ["com.google.chrome", "com.apple.safari"].contains(browser) else { return nil }
        self.browser = browser
        self.service = service
    }

    var label: String { service.rawValue + " Web · " + (browser == "com.google.chrome" ? "Chrome" : "Safari") }

    /// Only a digest of the visible chat route leaves the reader, for invalidating
    /// results if the user navigates while Vision is processing an earlier frame.
    func chatRoute(_ value: String) -> Data? {
        guard let url = URLComponents(string: value), url.scheme?.lowercased() == "https",
              url.user == nil, url.password == nil, url.port == nil || url.port == 443,
              let host = url.host?.lowercased() else { return nil }
        let path = url.percentEncodedPath
        let inChat: Bool
        switch service {
        case .zalo: inChat = host == "chat.zalo.me" && (path.isEmpty || path == "/")
        case .messenger:
            if ["messenger.com", "www.messenger.com"].contains(host) {
                inChat = path.isEmpty || path == "/" || path.hasPrefix("/t/") || path.hasPrefix("/e2ee/t/")
            } else {
                inChat = ["facebook.com", "www.facebook.com"].contains(host)
                    && (path == "/messages" || path == "/messages/" || path.hasPrefix("/messages/t/") || path.hasPrefix("/messages/e2ee/t/"))
            }
        }
        guard inChat else { return nil }
        return Data(SHA256.hash(data: Data(value.utf8)))
    }
}

actor MeetingBrowserReader {
    /// Only called with ask=true from the explicit remember-site button.
    func permitted(pid: pid_t, ask: Bool) -> Bool {
        let target = NSAppleEventDescriptor(processIdentifier: pid)
        return AEDeterminePermissionToAutomateTarget(target.aeDesc, kAECoreSuite, kAEGetData, ask) == noErr
    }

    func activeRoute(_ source: MeetingWebSource, pid: pid_t) -> Data? {
        guard permitted(pid: pid, ask: false), let event = Self.urlRequest(source, pid: pid) else { return nil }
        guard let reply = try? event.sendEvent(options: [.waitForReply, .neverInteract], timeout: 0.6),
              let value = reply.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else { return nil }
        return source.chatRoute(value)
    }

    static func urlRequest(_ source: MeetingWebSource, pid: pid_t) -> NSAppleEventDescriptor? {
        let chrome = source.browser == "com.google.chrome"
        // Scripting dictionary codes: active tab / URL in Chrome, current tab / URL in Safari.
        let tabCode: OSType = chrome ? 0x61635461 : 0x63546162
        let urlCode: OSType = chrome ? 0x55524C20 : 0x7055524C
        guard let front = object(cWindow, in: .null(), by: formAbsolutePosition, key: NSAppleEventDescriptor(int32: 1)),
              let tab = object(typeProperty, in: front, by: formPropertyID, key: NSAppleEventDescriptor(typeCode: tabCode)),
              let address = object(typeProperty, in: tab, by: formPropertyID, key: NSAppleEventDescriptor(typeCode: urlCode)) else { return nil }
        let event = NSAppleEventDescriptor(eventClass: kAECoreSuite, eventID: kAEGetData,
            targetDescriptor: NSAppleEventDescriptor(processIdentifier: pid),
            returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        event.setParam(address, forKeyword: keyDirectObject)
        return event
    }

    private static func object(_ type: OSType, in container: NSAppleEventDescriptor, by form: Int,
                               key: NSAppleEventDescriptor) -> NSAppleEventDescriptor? {
        let record = NSAppleEventDescriptor.record()
        record.setDescriptor(NSAppleEventDescriptor(typeCode: type), forKeyword: AEKeyword(keyAEDesiredClass))
        record.setDescriptor(container, forKeyword: AEKeyword(keyAEContainer))
        record.setDescriptor(NSAppleEventDescriptor(enumCode: OSType(form)), forKeyword: AEKeyword(keyAEKeyForm))
        record.setDescriptor(key, forKeyword: AEKeyword(keyAEKeyData))
        // The record has the complete typeObjectSpecifier layout.
        return record.coerce(toDescriptorType: typeObjectSpecifier)
    }
}
#endif
