import Foundation
import FRICore
import Testing

struct ManualActivityTests {
    @Test func acceptsWholeCountsAndLocaleGrouping() {
        for locale in [Locale(identifier: "en_US"), Locale(identifier: "vi_VN")] {
            for (input, expected) in [("0", 0), ("4321", 4321), ("100000", 100000), (" 0042 \n", 42)] {
                #expect(ManualActivity.steps(from: input, locale: locale) == expected)
            }
        }
        #expect(ManualActivity.steps(from: "4,321", locale: Locale(identifier: "en_US")) == 4321)
        #expect(ManualActivity.steps(from: "4.321", locale: Locale(identifier: "vi_VN")) == 4321)
        #expect(ManualActivity.steps(from: "1,00,000", locale: Locale(identifier: "en_IN")) == 100000)
        #expect(ManualActivity.steps(from: "٤٣٢١", locale: Locale(identifier: "ar")) == 4321)
    }

    @Test func rejectsInvalidOrPartialEntries() {
        for locale in [Locale(identifier: "en_US"), Locale(identifier: "vi_VN")] {
            for input in ["", " \n", "abc", "4321abc", "-1", "1.5", "1,5", "100001", "9999999999999999999999999999", "4,,321", "4..321"] {
                #expect(ManualActivity.steps(from: input, locale: locale) == nil, "Invalid whole-count input: \(input)")
            }
        }
    }
}
