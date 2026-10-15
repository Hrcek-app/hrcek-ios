import Foundation
import Synchronization
import Testing

@testable import HrcekKit

/// The queries a fake server was asked.
final class Asked: Sendable {
    let queries = Mutex<[String]>([])
    var all: [String] { queries.withLock { $0 } }
}

@MainActor
@Suite struct TagSuggestionTests {
    let page: SharedPage

    init() throws {
        page = SharedPage(url: try #require(URL(string: "https://example.com/a")), title: "A")
    }

    /// A model whose server answers labels from `labels`, after looking
    /// the page up and finding nothing.
    func model(
        labels: @escaping @Sendable (URLComponents) throws -> String,
        asked: Asked = Asked()
    ) async throws -> ShareModel {
        let session = StubURLProtocol.session { request in
            let url = try #require(request.url)
            if url.path() == "/api/fields/" {
                return (200, Data(#"{"items":[],"count":0}"#.utf8))
            }
            if url.path() == "/api/entries/lookup" {
                let notFound = #"{"error":{"code":"HRC-CORE-0003","message":"No.","details":{}}}"#
                return (404, Data(notFound.utf8))
            }
            #expect(url.path() == "/api/labels/")
            let parts = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
            asked.queries.withLock { $0.append(parts.percentEncodedQuery ?? "") }
            return (200, Data(try labels(parts).utf8))
        }
        let model = ShareModel(
            store: InMemoryCredentialStore(try sampleCredentials()), queue: temporaryQueue(),
            pages: .offline
        ) {
            EntryService(credentials: $0, language: "en", session: session)
        }
        model.suggestionDelay = .zero
        await model.start(page)
        return model
    }

    nonisolated static func labels(_ names: String...) -> String {
        let items = names.map { #"{"name":"\#($0)"}"# }.joined(separator: ",")
        return #"{"items":[\#(items)],"count":\#(names.count)}"#
    }

    @Test func suggestsTheAccountsLabelsForWhatIsTyped() async throws {
        let asked = Asked()
        let model = try await model(labels: { _ in Self.labels("watches", "water") }, asked: asked)
        model.tagText = "wat"
        await model.updateSuggestions()
        #expect(model.suggestions == ["watches", "water"])
        #expect(asked.all == ["starts_with=wat"])
    }

    @Test func neverSuggestsATagAlreadyAdded() async throws {
        let model = try await model(labels: { _ in Self.labels("watches", "water") })
        model.draft.addTag("Watches")
        model.tagText = "wat"
        await model.updateSuggestions()
        #expect(model.suggestions == ["water"])
    }

    @Test func asksNothingWhenNothingIsTyped() async throws {
        let asked = Asked()
        let model = try await model(labels: { _ in Self.labels("watches") }, asked: asked)
        model.tagText = "  "
        await model.updateSuggestions()
        #expect(model.suggestions.isEmpty)
        #expect(asked.all.isEmpty)
    }

    @Test func offersNoMoreThanEight() async throws {
        let names = (1...12).map { "tag\($0)" }
        let items = names.map { #"{"name":"\#($0)"}"# }.joined(separator: ",")
        let model = try await model(labels: { _ in #"{"items":[\#(items)],"count":12}"# })
        model.tagText = "tag"
        await model.updateSuggestions()
        #expect(model.suggestions.count == 8)
    }

    @Test func failingSuggestionsAreSimplyAbsent() async throws {
        let model = try await model(labels: { _ in throw URLError(.timedOut) })
        model.tagText = "wat"
        await model.updateSuggestions()
        #expect(model.suggestions.isEmpty)
        #expect(model.message == nil, "a missing convenience is not worth an error")
    }

    @Test func choosingASuggestionAddsIt() async throws {
        let model = try await model(labels: { _ in Self.labels("watches") })
        model.tagText = "wat"
        await model.updateSuggestions()
        model.choose("watches")
        #expect(model.draft.tags == ["watches"])
        #expect(model.tagText.isEmpty)
        #expect(model.suggestions.isEmpty)
    }

    @Test func addingWhatWasTypedPutsTheSuggestionsAway() async throws {
        let model = try await model(labels: { _ in Self.labels("watches") })
        model.tagText = "wat"
        await model.updateSuggestions()
        model.commitTagText()
        #expect(model.suggestions.isEmpty)
    }

    @Test func aLateAnswerDoesNotBringSuggestionsBack() async throws {
        let answer = DispatchSemaphore(value: 0)
        let asked = Asked()
        let model = try await model(
            labels: { _ in
                answer.wait()
                return Self.labels("watches")
            }, asked: asked)
        model.tagText = "wat"
        let suggesting = Task { await model.updateSuggestions() }
        for _ in 0..<500 where asked.all.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        model.choose("water")
        answer.signal()
        await suggesting.value
        #expect(model.suggestions.isEmpty)
    }
}
