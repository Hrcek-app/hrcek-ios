import Foundation
import Testing

@Suite("Slovenian plurals")
struct PluralTests {
    @Test(arguments: [
        (1, "1 vnos"), (2, "2 vnosa"), (3, "3 vnosi"), (4, "4 vnosi"),
        (5, "5 vnosov"), (101, "101 vnos"), (102, "102 vnosa"),
        (103, "103 vnosi"), (105, "105 vnosov"),
    ])
    func usesAllFourForms(count: Int, expected: String) throws {
        let path = try #require(Bundle.module.path(forResource: "sl", ofType: "lproj"))
        let slovenian = try #require(Bundle(path: path))
        let text = String(
            localized: "\(count) entries", bundle: slovenian, locale: Locale(identifier: "sl"))
        #expect(text == expected)
    }
}
