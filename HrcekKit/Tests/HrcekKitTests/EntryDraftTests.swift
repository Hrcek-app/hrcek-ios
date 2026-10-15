import Foundation
import Testing

@testable import HrcekKit

@Suite struct EntryDraftTests {
    @Test func startsFromTheSharedPage() throws {
        let page = SharedPage(url: try #require(URL(string: "https://example.com/a")), title: "A")
        let draft = EntryDraft(page: page)
        #expect(draft.url == "https://example.com/a")
        #expect(draft.title == "A")
        #expect(draft.notes.isEmpty)
        #expect(draft.tags.isEmpty)
    }

    @Test func startsFromTheEntryAlreadySaved() {
        let entry = EntryOut(
            id: 3, url: "https://example.com/a", title: "Old", notes: "Kept", tags: ["x", "y"])
        let draft = EntryDraft(entry: entry)
        #expect(draft.title == "Old")
        #expect(draft.notes == "Kept")
        #expect(draft.tags == ["x", "y"])
    }

    @Test func addsATagOnceIgnoringCapitals() {
        var draft = EntryDraft(url: "https://example.com/a")
        draft.addTag("  Watches ")
        draft.addTag("watches")
        draft.addTag("   ")
        #expect(draft.tags == ["Watches"])
    }

    @Test func removesATagIgnoringCapitals() {
        var draft = EntryDraft(url: "https://example.com/a")
        draft.addTag("Watches")
        draft.addTag("diving")
        draft.removeTag("WATCHES")
        #expect(draft.tags == ["diving"])
    }

    @Test func sendsTitleNotesAndTagsInFull() {
        var draft = EntryDraft(url: " https://example.com/a ")
        draft.title = "  A watch "
        draft.notes = "38mm\n"
        draft.addTag("watches")
        let request = draft.request()
        #expect(request.url == "https://example.com/a")
        #expect(request.title == "A watch")
        #expect(request.notes == "38mm\n")
        #expect(request.tags == ["watches"])
        #expect(request.fields == nil)
        #expect(request.imageUrl == nil)
    }

    @Test func fillsFromAKeptRequest() {
        let request = EntryIn(
            url: "https://example.com/a", title: "T", notes: "N", tags: ["x"],
            fields: ["Priority": "high"])
        let draft = EntryDraft(request: request, definitions: nil)
        #expect(draft.title == "T")
        #expect(draft.notes == "N")
        #expect(draft.tags == ["x"])
        #expect(draft.request().fields == ["Priority": "high"])
    }
}
