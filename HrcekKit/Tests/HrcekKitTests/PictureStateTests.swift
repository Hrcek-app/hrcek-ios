import Foundation
import Testing

@testable import HrcekKit

@Suite struct PictureStateTests {
    let first = URL(string: "https://example.com/first.jpg")
    let second = URL(string: "https://example.com/second.jpg")

    func candidates() throws -> [URL] {
        [try #require(first), try #require(second)]
    }

    @Test func aNewPageOffersItsFirstPicture() throws {
        let state = PictureState(candidates: try candidates(), held: nil, existing: false)
        #expect(state.included)
        #expect(state.selected == .candidate(try #require(first)))
        #expect(state.choice == .address(try #require(first)))
    }

    @Test func anEntryWithAPictureKeepsIt() throws {
        let state = PictureState(
            candidates: try candidates(), held: .shown(Data([1])), existing: true)
        #expect(state.included)
        #expect(state.items.first == .held(.shown(Data([1]))))
        #expect(state.selected == state.items.first)
        #expect(state.choice == .unchanged)
    }

    @Test func anEntryWithoutAPictureDoesNotQuietlyGainOne() throws {
        var state = PictureState(candidates: try candidates(), held: nil, existing: true)
        #expect(state.included == false)
        #expect(state.choice == .unchanged)
        state.included = true
        #expect(state.choice == .address(try #require(first)))
    }

    @Test func leavingOutAHeldPictureRemovesIt() throws {
        var state = PictureState(candidates: [], held: .unshowable, existing: true)
        state.included = false
        #expect(state.choice == .remove)
    }

    @Test func includingAgainKeepsTheChoice() throws {
        var state = PictureState(candidates: try candidates(), held: nil, existing: false)
        state.select(.candidate(try #require(second)))
        state.included = false
        #expect(state.choice == .unchanged)
        state.included = true
        #expect(state.choice == .address(try #require(second)))
    }

    @Test func canChangeOnlyWithSomethingElseToPick() throws {
        let one = PictureState(candidates: [try #require(first)], held: nil, existing: false)
        #expect(one.canChange == false)
        let two = PictureState(candidates: try candidates(), held: nil, existing: false)
        #expect(two.canChange)
    }

    @Test func nothingOnOfferIsNothingToInclude() {
        var state = PictureState(candidates: [], held: nil, existing: false)
        #expect(state.items.isEmpty)
        state.included = true
        #expect(state.included == false)
        #expect(state.choice == .unchanged)
    }

    @Test func choosingSomethingNotOnOfferChangesNothing() throws {
        var state = PictureState(candidates: try candidates(), held: nil, existing: false)
        state.select(.candidate(try #require(URL(string: "https://elsewhere.com/x.jpg"))))
        #expect(state.selected == .candidate(try #require(first)))
    }

    @Test func picturesFoundLaterJoinWhatIsOffered() throws {
        var state = PictureState(candidates: [], held: nil, existing: false)
        state.offer([try #require(first)])
        #expect(state.included)
        #expect(state.choice == .address(try #require(first)))
    }

    @Test func picturesFoundLaterKeepWhatThePersonDecided() throws {
        var state = PictureState(candidates: [], held: .unshowable, existing: true)
        state.included = false
        state.offer(try candidates())
        #expect(state.included == false)
        #expect(state.choice == .remove)
        #expect(state.items.count == 3)
    }
}
