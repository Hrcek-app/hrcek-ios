import Foundation
import Synchronization
import Testing

@testable import HrcekKit

@MainActor
@Suite struct FieldsShareTests {
    nonisolated static let fields =
        #"{"items":[{"name":"Priority","kind":"choice","options":["high","low"]}],"count":1}"#
    nonisolated static let held = #"""
        {"id":1,"url":"https://example.com/a","title":"Held","notes":"","tags":[],
         "fields":{"Priority":"low","Shop":"Ana"},"image":null}
        """#

    let page: SharedPage

    init() throws {
        page = SharedPage(url: try #require(URL(string: "https://example.com/a")), title: "A")
    }

    func model(held: String?, fields: String?, posted: Posted) throws -> ShareModel {
        let session = StubURLProtocol.session { request in
            switch request.url?.path() {
            case "/api/fields/":
                guard let fields else { throw URLError(.timedOut) }
                return (200, Data(fields.utf8))
            case "/api/entries/lookup":
                guard let held else { return (404, notFound) }
                return (200, Data(held.utf8))
            default:
                posted.bodies.withLock { $0.append(request.bodyData) }
                return (held == nil ? 201 : 200, Data((held ?? Self.held).utf8))
            }
        }
        return ShareModel(
            store: InMemoryCredentialStore(try sampleCredentials()), pages: .offline
        ) {
            EntryService(credentials: $0, language: "en", session: session)
        }
    }

    @Test func showsTheAccountsFieldsWithTheEntrysValues() async throws {
        let model = try model(held: Self.held, fields: Self.fields, posted: Posted())
        await model.start(page)
        #expect(model.draft.fields.map(\.name) == ["Priority"])
        #expect(model.draft.fields.first?.value == "low")
        #expect(model.fieldsUnavailable == false)
    }

    @Test func sendsTheFieldsItShowed() async throws {
        let posted = Posted()
        let model = try model(held: Self.held, fields: Self.fields, posted: posted)
        await model.start(page)
        model.draft.fields[0].value = "high"
        _ = await model.save()
        let body = try URLRequest.jsonObject(try #require(posted.bodies.withLock { $0.first }))
        // Shop was never shown, so it is never sent: it keeps its value.
        #expect(body["fields"] as? [String: String] == ["Priority": "high"])
    }

    @Test func saysSoAndKeepsTheEntrysFieldsWhenTheyCannotBeRead() async throws {
        let model = try model(held: Self.held, fields: nil, posted: Posted())
        await model.start(page)
        #expect(model.fieldsUnavailable)
        #expect(model.draft.fields.map(\.name) == ["Priority", "Shop"])
        #expect(model.phase == .editing)
    }

    @Test func sendsNoFieldsWhenThereAreNone() async throws {
        let posted = Posted()
        let model = try model(held: nil, fields: #"{"items":[],"count":0}"#, posted: posted)
        await model.start(page)
        _ = await model.save()
        let body = try URLRequest.jsonObject(try #require(posted.bodies.withLock { $0.first }))
        #expect(body["fields"] == nil)
    }
}

extension FieldsShareTests {
    /// Field names are the owner's free text; no JSON key conversion may touch them.
    @Test func keepsFieldNamesExactlyAsTheyAre() async throws {
        let names = ["start_date", "dueDate", "Due Date"]
        let items = names.map { #"{"name":"\#($0)","kind":"text","options":[]}"# }
        let fields = #"{"items":[\#(items.joined(separator: ","))],"count":3}"#
        let held = #"""
            {"id":1,"url":"https://example.com/a","title":"Held","notes":"","tags":[],
             "fields":{"start_date":"1","dueDate":"2","Due Date":"3"},"image":null}
            """#
        let posted = Posted()
        let model = try model(held: held, fields: fields, posted: posted)
        await model.start(page)
        #expect(model.draft.fields.map(\.value) == ["1", "2", "3"])
        _ = await model.save()
        let body = try URLRequest.jsonObject(try #require(posted.bodies.withLock { $0.first }))
        #expect(
            body["fields"] as? [String: String]
                == ["start_date": "1", "dueDate": "2", "Due Date": "3"])
    }
}

/// The bodies a fake server was sent.
final class Posted: Sendable {
    let bodies = Mutex<[Data]>([])
}
