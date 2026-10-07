import Foundation

public struct APIResponse<Value: Sendable>: Sendable {
    public let value: Value
    public let status: Int
}

/// Talks JSON to one Hrček server, in the app's language.
public struct APIClient: Sendable {
    /// The app's own localisation, so server messages match the UI.
    public static var preferredLanguage: String {
        Bundle.main.preferredLocalizations.first ?? "en"
    }

    private let server: ServerAddress
    private let token: String?
    private let language: String
    private let session: URLSession

    public init(
        server: ServerAddress, token: String? = nil,
        language: String = APIClient.preferredLanguage, session: URLSession = .shared
    ) {
        self.server = server
        self.token = token
        self.language = language
        self.session = session
    }

    public func get<Value: Decodable & Sendable>(
        _ path: String, as type: Value.Type
    ) async throws -> APIResponse<Value> {
        try await send(request("GET", path, body: nil))
    }

    public func post<Body: Encodable & Sendable, Value: Decodable & Sendable>(
        _ path: String, body: Body, as type: Value.Type
    ) async throws -> APIResponse<Value> {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return try await send(request("POST", path, body: try encoder.encode(body)))
    }

    private func request(_ method: String, _ path: String, body: Data?) -> URLRequest {
        var request = URLRequest(url: server.endpoint(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(language, forHTTPHeaderField: "Accept-Language")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private func send<Value: Decodable & Sendable>(
        _ request: URLRequest
    ) async throws -> APIResponse<Value> {
        let label = "\(request.httpMethod ?? "") \(request.url?.path() ?? "")"
        let started = ContinuousClock.now
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            Log.api.error("\(label, privacy: .public) failed: \(error.code.rawValue)")
            throw APIError.transport(error.code)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let elapsed = started.duration(to: .now)
        Log.api.info("\(label, privacy: .public) → \(status) in \(elapsed, privacy: .public)")
        #if DEBUG
            if let body = request.httpBody {
                Log.api.debug("request: \(LogRedaction.redacted(body), privacy: .public)")
            }
            Log.api.debug("response: \(LogRedaction.redacted(data), privacy: .public)")
        #endif
        return try decode(data, status: status)
    }

    private func decode<Value: Decodable & Sendable>(
        _ data: Data, status: Int
    ) throws -> APIResponse<Value> {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        if (200..<300).contains(status) {
            guard let value = try? decoder.decode(Value.self, from: data) else {
                throw APIError.unexpectedResponse(status: status)
            }
            return APIResponse(value: value, status: status)
        }
        guard let envelope = try? decoder.decode(ErrorEnvelope.self, from: data) else {
            throw APIError.unexpectedResponse(status: status)
        }
        Log.api.notice("server refused: \(envelope.error.code, privacy: .public)")
        throw APIError.server(
            status: status, code: envelope.error.code, message: envelope.error.message)
    }
}
