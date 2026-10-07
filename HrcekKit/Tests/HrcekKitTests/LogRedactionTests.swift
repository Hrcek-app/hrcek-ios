import Foundation
import Testing

@testable import HrcekKit

@Suite struct LogRedactionTests {
    @Test func hidesSecretsAtAnyDepth() {
        let json = #"""
            {"name":"x","password":"p","nested":{"token":"hrcek_test1","identifier":"a@b.c"}}
            """#
        let text = LogRedaction.redacted(Data(json.utf8))
        #expect(!text.contains("hrcek_test1"))
        #expect(!text.contains("\"p\""))
        #expect(!text.contains("a@b.c"))
        #expect(text.contains("\"name\":\"x\""))
    }

    @Test func describesWhatIsNotJSON() {
        #expect(LogRedaction.redacted(Data([0xff, 0x00])) == "<2 bytes>")
    }
}
