import Foundation
import Testing

@testable import HrcekKit

@Suite struct PageCandidatesTests {
    func body(_ url: String, _ width: Double, _ height: Double) -> PageCandidate {
        PageCandidate(url: url, width: width, height: height, fromHead: false)
    }

    func head(_ url: String) -> PageCandidate {
        PageCandidate(url: url, width: 0, height: 0, fromHead: true)
    }

    @Test func headFirstThenTheLargestImages() {
        let ranked = PageCandidate.rank([
            body("https://e.com/small.jpg", 200, 200),
            head("https://e.com/og.jpg"),
            body("https://e.com/big.jpg", 800, 600),
        ])
        #expect(
            ranked.map(\.absoluteString) == [
                "https://e.com/og.jpg", "https://e.com/big.jpg", "https://e.com/small.jpg",
            ])
    }

    @Test func eachPictureOnce() {
        let ranked = PageCandidate.rank([
            head("https://e.com/a.jpg"), body("https://e.com/a.jpg", 500, 500),
        ])
        #expect(ranked.count == 1)
    }

    @Test func dropsWhatTheServerWouldRefuseOrIsTooSmall() {
        let ranked = PageCandidate.rank([
            head("https://e.com/logo.svg"),
            head("https://e.com/logo.SVGZ?v=2"),
            head("data:image/png;base64,AAAA"),
            head("not an address"),
            body("https://e.com/icon.png", 99, 400),
            body("https://e.com/ok.png", 100, 100),
        ])
        #expect(ranked.map(\.absoluteString) == ["https://e.com/ok.png"])
    }

    @Test func aHeadPictureHasNoSizeToHoldAgainstIt() {
        #expect(PageCandidate.rank([head("https://e.com/og.jpg")]).count == 1)
    }

    @Test func noMoreThanSixty() {
        let many = (1...80).map { body("https://e.com/\($0).jpg", 200, 200) }
        #expect(PageCandidate.rank(many).count == 60)
    }
}
