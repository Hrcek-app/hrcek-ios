import HrcekKit
import SwiftUI

/// Whether the entry carries a picture, and which. Absent when there is
/// nothing to show.
struct PictureSection: View {
    @Bindable var model: ShareModel

    var body: some View {
        if !model.pictures.items.isEmpty {
            Section("Picture") {
                Toggle("Include picture", isOn: $model.pictures.included)
                    .accessibilityIdentifier("includePicture")
                if model.pictures.included, let selected = model.pictures.selected {
                    PictureImage(item: selected, side: 300)
                        .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 180)
                        .accessibilityIdentifier("selectedPicture")
                    if model.pictures.canChange {
                        NavigationLink("Change") { PictureChooser(model: model) }
                            .accessibilityIdentifier("changePicture")
                    }
                }
            }
        }
    }
}
