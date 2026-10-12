import Foundation

/// A field the account defines for its entries. Never hard-coded: they
/// are renamed and deleted by their owner.
public struct FieldOut: Decodable, Equatable, Sendable {
    public enum Kind: String, Decodable, Sendable {
        case text, number, choice

        // A kind added on the server later is still a value to show and send.
        public init(from decoder: any Decoder) throws {
            self = Kind(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .text
        }
    }

    public let name: String
    public let kind: Kind
    public let options: [String]

    public init(name: String, kind: Kind, options: [String]) {
        self.name = name
        self.kind = kind
        self.options = options
    }
}

/// One field on the form: what the account defines, and the entry's value.
public struct FieldInput: Equatable, Sendable, Identifiable {
    public let name: String
    public let kind: FieldOut.Kind
    public let options: [String]
    public var value: String

    public var id: String { name }

    /// A choice whose stored value the field no longer offers.
    public var isNoLongerOffered: Bool {
        kind == .choice && !value.isEmpty && !options.contains(value)
    }

    /// The inputs to show. Without definitions the entry's own fields
    /// stand in, so what it holds stays visible and is sent back intact.
    public static func inputs(definitions: [FieldOut]?, values: [String: String]) -> [FieldInput] {
        guard let definitions else {
            return values.keys.sorted().map { name in
                FieldInput(name: name, kind: .text, options: [], value: values[name] ?? "")
            }
        }
        return definitions.map { definition in
            FieldInput(
                name: definition.name, kind: definition.kind, options: definition.options,
                value: value(of: definition.name, in: values))
        }
    }

    /// What to send. `fields` is patched, so every field shown is sent and
    /// an empty one as "" to clear it; one never shown is never sent.
    public static func patch(_ inputs: [FieldInput]) -> [String: String] {
        var patch: [String: String] = [:]
        // The server would refuse a choice it no longer offers, and sending
        // "" instead would destroy it; left out, it stays as it is.
        for input in inputs where !input.isNoLongerOffered {
            patch[input.name] = input.value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return patch
    }

    // Names match without regard to case; another client may spell them differently.
    private static func value(of name: String, in values: [String: String]) -> String {
        values.first { $0.key.lowercased() == name.lowercased() }?.value ?? ""
    }
}
