import HrcekKit
import SwiftUI

/// One kept page: what it is, and what has become of it.
struct PendingRow: View {
    let entry: PendingEntry
    let picture: Data?
    let elsewhere: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: entry.request.title.isEmpty ? entry.url : entry.request.title)
                    .font(.headline).lineLimit(2)
                Text(verbatim: URL(string: entry.url)?.host() ?? entry.url)
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(entry.savedAt, format: .relative(presentation: .named))
                    .font(.caption).foregroundStyle(.secondary)
                if !entry.request.tags.isEmpty {
                    Text(verbatim: entry.request.tags.joined(separator: ", "))
                        .font(.caption)
                }
                status
            }
            Spacer(minLength: 0)
            if let picture { KeptPicture(data: picture, side: 56) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("pending-\(entry.request.title)")
    }

    @ViewBuilder private var status: some View {
        if elsewhere {
            Text("Saved for \(entry.server.host), which is not the server you're signed in to.")
                .font(.caption).foregroundStyle(.orange)
        } else {
            switch entry.state {
            case .waiting: EmptyView()
            case .held:
                Text("Hrček already has this page.").font(.caption).foregroundStyle(.orange)
            case .refused(let message):
                Text(verbatim: message).font(.caption).foregroundStyle(.red)
            }
        }
    }
}
