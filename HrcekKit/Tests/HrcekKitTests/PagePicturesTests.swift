import Foundation
import Testing

@testable import HrcekKit

@Suite struct PagePicturesTests {
    let base = URL(string: "https://example.com/watches/one")

    @Test func readsThePicturesAPageNamesInItsHead() throws {
        let html = """
            <html><head>
            <meta property="og:image" content="/og.jpg">
            <meta content='https://cdn.example.com/secure.jpg' property='og:image:secure_url' />
            <meta name="twitter:image" content="tw.jpg?a=1&amp;b=2">
            <link rel="image_src" href="https://example.com/link.jpg">
            <meta itemprop="image" content="https://example.com/item.jpg">
            <meta name="description" content="not a picture">
            </head><body><img src="body.jpg"></body></html>
            """
        let found = PagePictures.candidates(inHTML: html, base: try #require(base))
        #expect(
            found.map(\.url) == [
                "https://example.com/og.jpg", "https://cdn.example.com/secure.jpg",
                "https://example.com/watches/tw.jpg?a=1&b=2", "https://example.com/link.jpg",
                "https://example.com/item.jpg",
            ])
        #expect(found.allSatisfy { $0.fromHead })
    }

    @Test func findsNothingInAPageWithoutThem() throws {
        let found = PagePictures.candidates(
            inHTML: "<html><head><title>x</title></head></html>", base: try #require(base))
        #expect(found.isEmpty)
    }

    @Test func fetchesThePageAndRanksWhatItNames() async throws {
        let session = StubURLProtocol.session { request in
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            return (200, Data(#"<meta property="og:image" content="/og.jpg">"#.utf8))
        }
        let pictures = await PagePictures.fetch(try #require(base), session: session)
        #expect(pictures.map(\.absoluteString) == ["https://example.com/og.jpg"])
    }

    @Test func aPageThatCannotBeReadOffersNothing() async throws {
        let page = try #require(base)
        let session = StubURLProtocol.session { _ in throw URLError(.timedOut) }
        #expect(await PagePictures.fetch(page, session: session).isEmpty)
        let missing = StubURLProtocol.session(status: 404, json: "")
        #expect(await PagePictures.fetch(page, session: missing).isEmpty)
    }

    @Test func anEmptyNameIsNotThePageItself() throws {
        let html = #"<meta property="og:image" content=" "><meta name="twitter:image" content="">"#
        #expect(PagePictures.candidates(inHTML: html, base: try #require(base)).isEmpty)
    }

    @Test func readsNoMoreThanItNeeds() async throws {
        let session = StubURLProtocol.session { _ in (200, Data(count: 3_000_000)) }
        let start = try await session.data(for: URLRequest(url: try #require(base)), upTo: 1_000)
        #expect(start.data.count == 1_000)
        #expect(start.complete == false)
        let small = StubURLProtocol.session { _ in (200, Data(count: 10)) }
        let all = try await small.data(for: URLRequest(url: try #require(base)), upTo: 1_000)
        #expect(all.data.count == 10)
        #expect(all.complete)
    }
}
