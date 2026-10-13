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
        _ path: String, query: [URLQueryItem] = [], as type: Value.Type
    ) async throws -> APIResponse<Value> {
        try await send(request("GET", path, query: query, body: nil))
    }

    public func post<Body: Encodable & Sendable, Value: Decodable & Sendable>(
        _ path: String, body: Body, as type: Value.Type
    ) async throws -> APIResponse<Value> {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return try await send(request("POST", path, body: try encoder.encode(body)))
    }

    /// Sends a request whose answer has no body worth reading.
    public func delete(_ path: String) async throws {
        let (data, status) = try await perform(request("DELETE", path, body: nil))
        guard (200..<300).contains(status) else { throw failure(data, status: status) }
    }

    /// Uploads one file as multipart form data, as the picture route takes it.
    public func upload<Value: Decodable & Sendable>(
        _ path: String, file: Data, filename: String, type: String, as kind: Value.Type
    ) async throws -> APIResponse<Value> {
        let boundary = "hrcek-\(UUID().uuidString)"
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        let quoted = filename.replacingOccurrences(of: "\"", with: "")
        body.append(
            Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(quoted)\"\r\n".utf8))
        body.append(Data("Content-Type: \(type)\r\n\r\n".utf8))
        body.append(file)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        var request = request("POST", path, body: body)
        request.setValue(
            "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        return try await send(request)
    }

    /// The raw bytes at `path` and their content type.
    public func data(_ path: String, accept: String) async throws -> (Data, String?) {
        var request = request("GET", path, body: nil)
        request.setValue(accept, forHTTPHeaderField: "Accept")
        let (data, response) = try await exchange(request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw failure(data, status: status) }
        return (data, response.mimeType)
    }

    private func request(
        _ method: String, _ path: String, query: [URLQueryItem] = [], body: Data?
    ) -> URLRequest {
        let url = server.endpoint(path)
        var request = URLRequest(url: query.isEmpty ? url : url.appending(queryItems: query))
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
        let (data, status) = try await perform(request)
        return try decode(data, status: status)
    }

    private func perform(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, response) = try await exchange(request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    private func exchange(_ request: URLRequest) async throws -> (Data, URLResponse) {
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
            // Bodies that are not JSON are pictures: neither readable nor redactable.
            if let body = request.httpBody,
                request.value(forHTTPHeaderField: "Content-Type") == "application/json"
            {
                Log.api.debug("request: \(LogRedaction.redacted(body), privacy: .public)")
            }
            if response.mimeType == "application/json" {
                Log.api.debug("response: \(LogRedaction.redacted(data), privacy: .public)")
            }
        #endif
        return (data, response)
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
        throw failure(data, status: status)
    }

    private func failure(_ data: Data, status: Int) -> APIError {
        let decoder = JSONDecoder()
        guard let envelope = try? decoder.decode(ErrorEnvelope.self, from: data) else {
            return .unexpectedResponse(status: status)
        }
        Log.api.notice("server refused: \(envelope.error.code, privacy: .public)")
        return .server(status: status, code: envelope.error.code, message: envelope.error.message)
    }
}
