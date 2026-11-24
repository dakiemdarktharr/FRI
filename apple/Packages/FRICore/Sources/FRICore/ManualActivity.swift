import Foundation

public enum ManualActivity {
    /// Parse the complete entry, never a numeric prefix or a previously valid field value.
    public static func steps(from text: String, locale: Locale = .current) -> Int? {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let separator = formatter.groupingSeparator ?? ""
        let grouped = !separator.isEmpty && input.contains(separator)
        let digits = grouped ? input.replacingOccurrences(of: separator, with: "") : input
        guard !digits.isEmpty,
              digits.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) }) else { return nil }
        let normalized = digits.compactMap(\.wholeNumberValue).map(String.init).joined()
        guard let value = Int(normalized), (0...100_000).contains(value) else { return nil }
        // Reject malformed grouping such as 1.5 in a locale whose separator is a dot.
        if grouped, formatter.string(from: NSNumber(value: value)) != input { return nil }
        return value
    }
}
