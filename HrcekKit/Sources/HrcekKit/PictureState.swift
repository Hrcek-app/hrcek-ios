import Foundation

/// The picture an entry already holds.
public enum HeldPicture: Equatable, Sendable {
    case shown(Data)
    /// It has one, but its bytes could not be had.
    case unshowable
}

/// One picture on offer: the one the entry holds, or one the page offers.
public enum PictureItem: Hashable, Sendable {
    case held(HeldPicture)
    case candidate(URL)
}

// Views use pictures as identities on every update; hashing a whole
// picture each time would be slow, and its size tells them apart enough.
extension HeldPicture: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .shown(let data): hasher.combine(data.count)
        case .unshowable: hasher.combine(-1)
        }
    }
}

/// What saving does about the picture.
public enum PictureChoice: Equatable, Sendable {
    case unchanged, remove
    case address(URL)
}

/// The picture row and the chooser, without any view: what is on offer,
/// whether one is included, which one.
public struct PictureState: Equatable, Sendable {
    /// The held picture first, then the page's.
    public private(set) var items: [PictureItem]
    public private(set) var selected: PictureItem?
    private var include: Bool
    private let held: HeldPicture?
    private let existing: Bool

    public init(candidates: [URL], held: HeldPicture?, existing: Bool) {
        self.held = held
        self.existing = existing
        items = []
        selected = nil
        include = false
        offer(candidates)
    }

    /// Adds the page's pictures, which may arrive after the form opened.
    /// Whatever the person already decided stands.
    public mutating func offer(_ candidates: [URL]) {
        let first = items.isEmpty
        items = (held.map { [PictureItem.held($0)] } ?? []) + candidates.map(PictureItem.candidate)
        selected = selected ?? items.first
        // A held picture is a choice already made and a new page a proposal;
        // an entry saved without one must not quietly gain one.
        if first { include = !items.isEmpty && (held != nil || !existing) }
    }

    public static let none = PictureState(candidates: [], held: nil, existing: false)

    /// What a kept copy says of its picture, offered as an entry's would be:
    /// its bytes as the held picture, else its address first.
    init(kept picture: PendingEntry.Picture?, data: Data?, offered: [URL]) {
        switch picture {
        case .bytes:
            self.init(
                candidates: offered, held: data.map(HeldPicture.shown) ?? .unshowable,
                existing: true)
        case .address(let url):
            self.init(candidates: [url] + offered, held: nil, existing: false)
        case .remove, nil:
            self.init(candidates: offered, held: nil, existing: true)
        }
    }

    public var included: Bool {
        get { include }
        set { include = newValue && !items.isEmpty }
    }

    /// Whether there is anything else to pick.
    public var canChange: Bool { items.count > 1 }

    public mutating func select(_ item: PictureItem) {
        if items.contains(item) { selected = item }
    }

    public var choice: PictureChoice {
        guard include else { return held != nil ? .remove : .unchanged }
        guard case .candidate(let url) = selected else { return .unchanged }
        return .address(url)
    }
}
