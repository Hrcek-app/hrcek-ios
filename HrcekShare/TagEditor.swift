import HrcekKit
import SwiftUI

/// Tags as chips, and a field to add more.
struct TagEditor: View {
    @Bindable var model: ShareModel
    @FocusState private var typing: Bool

    static let fieldID = "tagField"

    var body: some View {
        if !model.draft.tags.isEmpty {
            FlowLayout(spacing: 8) {
                ForEach(model.draft.tags, id: \.self) { tag in
                    Button {
                        model.draft.removeTag(tag)
                    } label: {
                        Label(tag, systemImage: "xmark").labelStyle(TrailingIcon())
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(Text("Remove \(tag)"))
                    .accessibilityIdentifier("tag-\(tag)")
                }
            }
        }
        TextField("Add a tag", text: $model.tagText)
            .textInputAutocapitalization(.never)
            .submitLabel(.done)
            .focused($typing)
            .onSubmit {
                model.commitTagText()
                // Keep the keyboard up for the next tag.
                typing = true
            }
            .onChange(of: model.tagText) { _, text in
                if text.contains(",") { model.commitTagText() }
            }
            // A new keystroke cancels the previous lookup.
            .task(id: model.tagText) { await model.updateSuggestions() }
            .accessibilityIdentifier("tagField")
            .id(Self.fieldID)
        ForEach(model.suggestions, id: \.self) { label in
            Button {
                model.choose(label)
                typing = true
            } label: {
                Label(label, systemImage: "plus.circle")
            }
            .accessibilityIdentifier("suggestion-\(label)")
        }
    }
}

private struct TrailingIcon: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon.font(.caption2)
        }
    }
}
