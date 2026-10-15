import Foundation
import HrcekKit
import Testing

@Suite struct PendingQueueContainerTests {
    /// Without the group, the extension would keep saves the app never sees.
    @Test func theQueueLivesInTheAppGroup() throws {
        let group = try #require(
            Bundle.main.object(forInfoDictionaryKey: "HrcekAppGroup") as? String)
        let container = try #require(
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group))
        #expect(container.path().isEmpty == false)
    }
}
