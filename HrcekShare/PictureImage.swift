import HrcekKit
import SwiftUI

/// One picture on offer, loaded small enough for the extension's memory.
struct PictureImage: View {
    let item: PictureItem
    /// The longest side to decode, in points.
    let side: CGFloat
    var fill = false

    @Environment(\.displayScale) private var scale
    @State private var image: CGImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: scale)
                    .resizable()
                    .aspectRatio(contentMode: fill ? .fill : .fit)
            } else if failed {
                Unshowable()
            } else {
                ProgressView()
            }
        }
        .task(id: item) { await load() }
    }

    private func load() async {
        let pixels = Int(side * scale)
        switch item {
        case .held(.shown(let data)):
            image = PictureLoader.image(from: data, side: pixels)
        case .held(.unshowable):
            image = nil
        case .candidate(let url):
            image = await PictureLoader.shared.image(at: url, side: pixels)
        }
        failed = image == nil
    }
}

/// Where a picture would be, said in words.
struct Unshowable: View {
    var body: some View {
        Label("It has a picture that cannot be shown here", systemImage: "photo")
            .font(.footnote).foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
