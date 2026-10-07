import Foundation

/// Makes request and response bodies safe for debug logs.
public enum LogRedaction {
    static let secretKeys: Set<String> = ["password", "token", "identifier", "email"]

    public static func redacted(_ data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data),
            let clean = try? JSONSerialization.data(
                withJSONObject: scrub(object), options: [.sortedKeys, .withoutEscapingSlashes]),
            let text = String(data: clean, encoding: .utf8)
        else { return "<\(data.count) bytes>" }
        return text
    }

    private static func scrub(_ value: Any) -> Any {
        switch value {
        case let dictionary as [String: Any]:
            dictionary.reduce(into: [String: Any]()) { result, pair in
                result[pair.key] =
                    secretKeys.contains(pair.key) ? "‹redacted›" : scrub(pair.value)
            }
        case let array as [Any]:
            array.map(scrub)
        default:
            value
        }
    }
}
