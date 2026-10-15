import HrcekKit
import SwiftUI

/// A kept picture, decoded no larger than it is drawn.
struct KeptPicture: View {
    let data: Data
    let side: CGFloat
    @Environment(\.displayScale) private var scale

    var body: some View {
        if let image = PictureLoader.image(from: data, side: Int(side * scale)) {
            Image(decorative: image, scale: scale)
                .resizable().scaledToFill()
                .frame(width: side, height: side).clipped()
                .clipShape(.rect(cornerRadius: 6))
        }
    }
}
