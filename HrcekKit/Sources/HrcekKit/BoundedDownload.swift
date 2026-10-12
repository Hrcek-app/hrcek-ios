import Foundation

extension URLSession {
    /// At most `limit` bytes of the answer, and whether that was all of it.
    /// The share extension is given little memory; a shared link can lead
    /// to a video, and a picture to its full-size original.
    func data(for request: URLRequest, upTo limit: Int) async throws -> (Data, Bool) {
        let (bytes, response) = try await bytes(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode,
            (200..<300).contains(status)
        else {
            bytes.task.cancel()
            throw URLError(.badServerResponse)
        }
        var data = Data()
        data.reserveCapacity(min(max(Int(response.expectedContentLength), 0), limit))
        for try await byte in bytes {
            if data.count == limit {
                bytes.task.cancel()
                return (data, false)
            }
            data.append(byte)
        }
        return (data, true)
    }
}

extension Log {
    /// What went wrong, without the address it went wrong at: a URLError
    /// carries the page or picture address, which is the person's browsing.
    static func summary(of error: any Error) -> String {
        if let error = error as? URLError { return "URLError \(error.code.rawValue)" }
        return String(describing: type(of: error))
    }
}
