import Foundation
import Synchronization
import Testing

@testable import HrcekKit

/// A fake Hrček that understands pictures, recording what it was sent.
final class FakePictures: Sendable {
    typealias Reply = StubURLProtocol.Reply

    struct Request {
        let method: String
        let path: String
        let body: Data
    }

    struct State {
        var held = false
        var heldImage = false
        var heldBytes = Reply(status: 200, body: Data(), type: "image/png")
        var refuseAddresses = false
        var refuseUploads = false
        var requests: [Request] = []
    }

    let state: Mutex<State>

    init(held: Bool = false, heldImage: Bool = false) {
        state = Mutex(State(held: held, heldImage: heldImage))
    }

    func requests(_ method: String, _ path: String) -> [Data] {
        state.withLock { $0.requests }.filter { $0.method == method && $0.path == path }
            .map(\.body)
    }

    func firstPost() throws -> [String: Any] {
        try URLRequest.jsonObject(try #require(requests("POST", "/api/entries/").first))
    }

    func handle(_ request: URLRequest) -> Reply {
        state.withLock { state in
            let method = request.httpMethod ?? "GET"
            let path = request.url?.path() ?? ""
            state.requests.append(Request(method: method, path: path, body: request.bodyData))
            switch (method, path) {
            case ("GET", "/api/fields/"):
                return Reply(status: 200, body: Data(#"{"items":[],"count":0}"#.utf8))
            case ("POST", "/api/entries/lookup"):
                return state.held ? entry(state) : Reply(status: 404, body: notFound)
            case ("POST", "/api/entries/"):
                return save(request, &state)
            default:
                return picture(method, path, &state)
            }
        }
    }

    private func save(_ request: URLRequest, _ state: inout State) -> Reply {
        let body = (try? URLRequest.jsonObject(request.bodyData)) ?? [:]
        if state.refuseAddresses, body["image_url"] != nil {
            return refusal("HRC-IMAGE-0005", "Not there.")
        }
        let created = !state.held
        state.held = true
        return entry(state, status: created ? 201 : 200)
    }

    private func picture(_ method: String, _ path: String, _ state: inout State) -> Reply {
        switch (method, path) {
        case ("POST", "/api/entries/1/image"):
            if state.refuseUploads { return refusal("HRC-IMAGE-0001", "Not a picture.") }
            state.heldImage = true
            return entry(state)
        case ("DELETE", "/api/entries/1/image"):
            state.heldImage = false
            return Reply(status: 204, body: Data())
        case ("GET", "/entries/1/image/"):
            return state.heldBytes
        default:
            return Reply(status: 404, body: notFound)
        }
    }

    private func entry(_ state: State, status: Int = 200) -> Reply {
        let picture =
            state.heldImage ? #"{"url":"/entries/1/image/","width":10,"height":10}"# : "null"
        let body = #"""
            {"id":1,"url":"https://example.com/a","title":"A","notes":"","tags":[],"fields":{},
             "image":\#(picture)}
            """#
        return Reply(status: status, body: Data(body.utf8))
    }

    private func refusal(_ code: String, _ message: String) -> Reply {
        let body = #"{"error":{"code":"\#(code)","message":"\#(message)","details":{}}}"#
        return Reply(status: 422, body: Data(body.utf8))
    }
}

@MainActor
@Suite struct PictureSaveTests {
    let page: SharedPage
    let picture = URL(string: "https://cdn.example.com/watch.jpg")

    init() throws {
        page = SharedPage(
            url: try #require(URL(string: "https://example.com/a")), title: "A",
            pictures: [try #require(picture)])
    }

    func model(_ fake: FakePictures, bytes: PictureBytes?) throws -> ShareModel {
        let session = StubURLProtocol.typedSession { fake.handle($0) }
        let pages = PageAccess(pictures: { _ in [] }, bytes: { _ in bytes })
        return ShareModel(
            store: InMemoryCredentialStore(try sampleCredentials()), pages: pages
        ) { EntryService(credentials: $0, language: "en", session: session) }
    }

    let jpeg = PictureBytes(
        data: Data([0xFF, 0xD8, 0xFF]), type: "image/jpeg", filename: "watch.jpg")

    static func trouble(_ reason: String) -> String {
        "The entry was saved, but the picture could not be attached: \(reason)"
    }

    @Test func uploadsThePicturesBytes() async throws {
        let fake = FakePictures()
        let model = try model(fake, bytes: jpeg)
        await model.start(page)
        #expect(await model.save())
        let posted = try fake.firstPost()
        #expect(posted["image_url"] == nil, "the bytes are in hand; the address is not needed")
        let upload = try #require(fake.requests("POST", "/api/entries/1/image").first)
        let header = Data(#"name="file"; filename="watch.jpg""#.utf8)
        #expect(upload.range(of: header) != nil)
        #expect(upload.range(of: Data([0xFF, 0xD8, 0xFF])) != nil)
        #expect(model.pictureTrouble == nil)
    }

    @Test func givesTheAddressWhenTheBytesCannotBeHad() async throws {
        let fake = FakePictures()
        let model = try model(fake, bytes: nil)
        await model.start(page)
        #expect(await model.save())
        let posted = try fake.firstPost()
        #expect(posted["image_url"] as? String == picture?.absoluteString)
        #expect(fake.requests("POST", "/api/entries/1/image").isEmpty)
    }

    @Test func aRefusedAddressNeverCostsTheEntry() async throws {
        let fake = FakePictures()
        fake.state.withLock { $0.refuseAddresses = true }
        let model = try model(fake, bytes: nil)
        await model.start(page)
        #expect(await model.save())
        #expect(model.phase == .saved(created: true))
        #expect(fake.requests("POST", "/api/entries/").count == 2)
        #expect(model.pictureTrouble == Self.trouble("Not there."))
    }

    @Test func aRefusedUploadNeverCostsTheEntry() async throws {
        let fake = FakePictures()
        fake.state.withLock { $0.refuseUploads = true }
        let model = try model(fake, bytes: jpeg)
        await model.start(page)
        #expect(await model.save())
        #expect(model.phase == .saved(created: true))
        #expect(model.pictureTrouble == Self.trouble("Not a picture."))
    }

    @Test func removesAPictureLeftOut() async throws {
        let fake = FakePictures(held: true, heldImage: true)
        let model = try model(fake, bytes: nil)
        await model.start(page)
        model.pictures.included = false
        #expect(await model.save())
        #expect(fake.requests("DELETE", "/api/entries/1/image").count == 1)
    }

    @Test func leavesAPictureKeptAlone() async throws {
        let fake = FakePictures(held: true, heldImage: true)
        let model = try model(fake, bytes: jpeg)
        await model.start(page)
        #expect(await model.save())
        let posted = try fake.firstPost()
        #expect(posted["image_url"] == nil)
        #expect(fake.requests("POST", "/api/entries/1/image").isEmpty)
        #expect(fake.requests("DELETE", "/api/entries/1/image").isEmpty)
    }

    @Test func showsThePictureAnEntryHolds() async throws {
        let fake = FakePictures(held: true, heldImage: true)
        fake.state.withLock {
            $0.heldBytes = .init(status: 200, body: Data([1, 2, 3]), type: "image/webp")
        }
        let model = try model(fake, bytes: nil)
        await model.start(page)
        #expect(model.pictures.items.first == .held(.shown(Data([1, 2, 3]))))
    }

    @Test func saysSoWhenTheHeldPictureCannotBeShown() async throws {
        // A Hrček from before this address took a token answers its sign-in page.
        let fake = FakePictures(held: true, heldImage: true)
        fake.state.withLock {
            $0.heldBytes = .init(status: 200, body: Data("<html>".utf8), type: "text/html")
        }
        let model = try model(fake, bytes: nil)
        await model.start(page)
        #expect(model.pictures.items.first == .held(.unshowable))
        #expect(model.pictures.choice == .unchanged)
    }

    @Test func readsThePageWhenTheBrowserDidNot() async throws {
        let bare = SharedPage(url: try #require(URL(string: "https://example.com/a")), title: "A")
        let found = try #require(picture)
        let session = StubURLProtocol.typedSession { FakePictures().handle($0) }
        let pages = PageAccess(pictures: { _ in [found] }, bytes: { _ in nil })
        let model = ShareModel(
            store: InMemoryCredentialStore(try sampleCredentials()), pages: pages
        ) { EntryService(credentials: $0, language: "en", session: session) }
        await model.start(bare)
        #expect(model.pictures.items == [.candidate(found)])
    }

    @Test func opensTheFormBeforeThePageIsRead() async throws {
        let bare = SharedPage(url: try #require(URL(string: "https://example.com/a")), title: "A")
        let found = try #require(picture)
        let (gate, open) = AsyncStream<Void>.makeStream()
        let session = StubURLProtocol.typedSession { FakePictures().handle($0) }
        let pages = PageAccess(
            pictures: { _ in
                for await _ in gate { break }
                return [found]
            }, bytes: { _ in nil })
        let model = ShareModel(
            store: InMemoryCredentialStore(try sampleCredentials()), pages: pages
        ) { EntryService(credentials: $0, language: "en", session: session) }
        let starting = Task { await model.start(bare) }
        for _ in 0..<500 where model.phase != .editing {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(model.phase == .editing, "a slow page must not keep the form closed")
        #expect(model.pictures.items.isEmpty)
        open.yield()
        await starting.value
        #expect(model.pictures.items == [.candidate(found)])
        #expect(model.pictures.included)
    }
}
