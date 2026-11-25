import Foundation
import JavaScriptCore

/// Owned by one serial executor. No transcripts are written to the calendar.
public final class MeetingRecognition {
    private let detector: JSValue
    public init() throws {
        guard let url = Bundle.module.url(forResource: "meeting-agent", withExtension: "js"),
              let context = JSContext() else { throw SourceFailure("Missing local meeting detector.") }
        context.evaluateScript(try String(contentsOf: url, encoding: .utf8))
        guard let value = context.evaluateScript("new FRIMeetingAgent.MeetingFrames()"),
              value.isObject else { throw SourceFailure("Could not start the local meeting detector.") }
        detector = value
    }
    public func reset() { detector.invokeMethod("reset", withArguments: []) }
    public func observe(_ rows: [[String: String]], at date: Date = .now) -> [String: String]? {
        fields(detector.invokeMethod("observe", withArguments: [rows, date.timeIntervalSince1970 * 1000]))
    }

    public func draft(_ text: String, at date: Date = .now) -> [String: String]? {
        fields(detector.invokeMethod("draft", withArguments: [text, date.timeIntervalSince1970 * 1000]))
    }

    private func fields(_ result: JSValue?) -> [String: String]? {
        guard let result, result.isObject, let fields = result.toDictionary() else { return nil }
        return fields.reduce(into: [:]) { output, pair in
            if let key = pair.key as? String, let value = pair.value as? String { output[key] = value }
        }
    }
}
