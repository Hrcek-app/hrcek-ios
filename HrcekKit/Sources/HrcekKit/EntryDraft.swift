import Foundation

/// What the share sheet's form holds: the page, or the entry already saved
/// for it, as the person edits it.
public struct EntryDraft: Equatable, Sendable {
    public let url: String
    public var title: String
    public var notes: String
    public private(set) var tags: [String]
    public var fields: [FieldInput]

    public init(
        url: String, title: String = "", notes: String = "", tags: [String] = [],
        fields: [FieldInput] = []
    ) {
        self.url = url
        self.title = title
        self.notes = notes
        self.tags = tags
        self.fields = fields
    }

    public init(page: SharedPage, definitions: [FieldOut]? = nil) {
        self.init(
            url: page.url.absoluteString, title: page.title ?? "",
            fields: FieldInput.inputs(definitions: definitions, values: [:]))
    }

    public init(entry: EntryOut, definitions: [FieldOut]? = nil) {
        self.init(
            url: entry.url, title: entry.title, notes: entry.notes, tags: entry.tags,
            fields: FieldInput.inputs(definitions: definitions, values: entry.fields))
    }

    /// The server cannot hold two labels differing only by case, so neither can this.
    public mutating func addTag(_ raw: String) {
        let tag = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty, !tags.contains(where: { Self.same($0, tag) }) else { return }
        tags.append(tag)
    }

    public mutating func removeTag(_ tag: String) {
        tags.removeAll { Self.same($0, tag) }
    }

    /// Title, notes and tags always go in full: the save replaces them.
    public func request() -> EntryIn {
        EntryIn(
            url: url.trimmingCharacters(in: .whitespacesAndNewlines),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes, tags: tags,
            fields: fields.isEmpty ? nil : FieldInput.patch(fields))
    }

    static func same(_ first: String, _ second: String) -> Bool {
        first.trimmingCharacters(in: .whitespaces).lowercased()
            == second.trimmingCharacters(in: .whitespaces).lowercased()
    }
}
