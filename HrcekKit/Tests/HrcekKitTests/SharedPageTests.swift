import Foundation
import Testing

@testable import HrcekKit

@MainActor
@Suite struct SharedPageTests {
    func item(url: URL? = nil, text: String? = nil, title: String? = nil) -> NSExtensionItem {
        let item = NSExtensionItem()
        var providers: [NSItemProvider] = []
        if let url { providers.append(NSItemProvider(object: url as NSURL)) }
        if let text { providers.append(NSItemProvider(object: text as NSString)) }
        item.attachments = providers
        if let title { item.attributedTitle = NSAttributedString(string: title) }
        return item
    }

    @Test func readsTheURLAndTitle() async throws {
        let url = try #require(URL(string: "https://example.com/a"))
        let page = await SharedPage.from([item(url: url, title: "A page")])
        #expect(page == SharedPage(url: url, title: "A page"))
    }

    @Test func findsAURLInSharedText() async throws {
        let page = await SharedPage.from([item(text: "Look at this: https://example.com/b nice")])
        #expect(page?.url.absoluteString == "https://example.com/b")
    }

    @Test func ignoresATitleThatIsJustTheAddress() async throws {
        let url = try #require(URL(string: "https://example.com/a"))
        let page = await SharedPage.from([item(url: url, title: "https://example.com/a")])
        #expect(page?.title == nil)
    }

    @Test func ignoresWhatIsNotAWebPage() async {
        #expect(await SharedPage.from([item(text: "no address here")]) == nil)
        #expect(await SharedPage.from([item(url: URL(fileURLWithPath: "/tmp/x"))]) == nil)
        #expect(await SharedPage.from([]) == nil)
    }
}
