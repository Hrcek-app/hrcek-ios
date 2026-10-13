import HrcekKit
import SwiftUI

/// Every picture on offer, the selected one large enough to judge.
struct PictureChooser: View {
    @Bindable var model: ShareModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            if let selected = model.pictures.selected {
                Button {
                    dismiss()
                } label: {
                    PictureImage(item: selected, side: 600)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(alignment: .topLeading) { Caption("Selected") }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Use this picture"))
                .accessibilityIdentifier("chooserPreview")
            }
            strip
        }
        .padding()
        .navigationTitle("Choose a picture")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var strip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 8) {
                    let items = Array(model.pictures.items.enumerated())
                    ForEach(items, id: \.element) { index, item in
                        tile(item, number: index + 1)
                    }
                }
            }
            .frame(height: 88)
            .onAppear { proxy.scrollTo(model.pictures.selected, anchor: .center) }
        }
    }

    private func tile(_ item: PictureItem, number: Int) -> some View {
        let isSelected = item == model.pictures.selected
        return Button {
            model.pictures.select(item)
        } label: {
            PictureImage(item: item, side: 80, fill: true)
                .frame(width: 80, height: 80)
                .clipShape(.rect(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 3)
                }
                .overlay(alignment: .bottomLeading) {
                    if case .held = item { Caption("current") }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label(for: item, number: number))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("picture-\(number)")
        .id(item)
    }

    private func label(for item: PictureItem, number: Int) -> Text {
        switch item {
        case .held(.shown): Text("The picture it has")
        case .held(.unshowable): Text("It has a picture that cannot be shown here")
        case .candidate: Text("Picture \(number) of \(model.pictures.items.count)")
        }
    }
}

private struct Caption: View {
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(.thinMaterial, in: .capsule)
            .padding(6)
    }
}
