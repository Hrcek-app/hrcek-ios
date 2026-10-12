import Foundation
import Testing

@testable import HrcekKit

@Suite struct FieldInputTests {
    let definitions = [
        FieldOut(name: "Price", kind: .number, options: []),
        FieldOut(name: "Priority", kind: .choice, options: ["high", "medium", "low"]),
        FieldOut(name: "Shop", kind: .text, options: []),
    ]

    @Test func oneInputPerDefinitionWithTheEntrysValue() {
        let inputs = FieldInput.inputs(
            definitions: definitions, values: ["price": "129", "PRIORITY": "high"])
        #expect(inputs.map(\.name) == ["Price", "Priority", "Shop"])
        #expect(inputs.map(\.value) == ["129", "high", ""])
        #expect(inputs[1].options == ["high", "medium", "low"])
    }

    @Test func theEntrysOwnFieldsStandInWhenDefinitionsAreMissing() {
        let inputs = FieldInput.inputs(definitions: nil, values: ["Shop": "Ana", "Price": "5"])
        #expect(inputs.map(\.name) == ["Price", "Shop"])
        #expect(inputs.allSatisfy { $0.kind == .text })
        #expect(inputs.map(\.value) == ["5", "Ana"])
    }

    @Test func sendsEveryFieldShownAndClearsTheEmptyOnes() {
        var inputs = FieldInput.inputs(definitions: definitions, values: ["Price": "129"])
        inputs[0].value = "  "
        inputs[2].value = " Ana "
        #expect(FieldInput.patch(inputs) == ["Price": "", "Priority": "", "Shop": "Ana"])
    }

    @Test func leavesAChoiceNoLongerOfferedAlone() {
        let inputs = FieldInput.inputs(definitions: definitions, values: ["Priority": "urgent"])
        #expect(inputs[1].isNoLongerOffered)
        #expect(FieldInput.patch(inputs)["Priority"] == nil)
    }

    @Test func anUnknownKindIsTreatedAsText() throws {
        let json = #"{"items":[{"name":"Colour","kind":"colour","options":[]}],"count":1}"#
        let decoder = JSONDecoder()
        let page = try decoder.decode(Page<FieldOut>.self, from: Data(json.utf8))
        #expect(page.items.first?.kind == .text)
    }
}
