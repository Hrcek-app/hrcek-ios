import HrcekKit
import SwiftUI

/// The account's own fields, folded away: most saves never touch them.
struct FieldsSection: View {
    @Bindable var model: ShareModel
    @State private var expanded = false

    var body: some View {
        if model.fieldsUnavailable {
            Section {
                Text("Your fields could not be loaded — saving will not change them.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("fieldsUnavailable")
            }
        }
        if !model.draft.fields.isEmpty {
            Section {
                DisclosureGroup(isExpanded: $expanded) {
                    ForEach($model.draft.fields) { $field in
                        FieldRow(field: $field)
                    }
                } label: {
                    Text("Your fields").accessibilityIdentifier("yourFields")
                }
            }
        }
    }
}

private struct FieldRow: View {
    @Binding var field: FieldInput

    var body: some View {
        switch field.kind {
        case .choice:
            Picker(field.name, selection: $field.value) {
                Text(verbatim: "—").tag("")
                ForEach(field.options, id: \.self) { Text(verbatim: $0).tag($0) }
                // Hiding it would let Save clear it without anybody choosing to.
                if field.isNoLongerOffered {
                    Text("\(field.value) (no longer offered)").tag(field.value)
                }
            }
            .accessibilityIdentifier("field-\(field.name)")
        case .number, .text:
            LabeledContent(field.name) {
                TextField(field.name, text: $field.value)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(field.kind == .number ? .decimalPad : .default)
                    .accessibilityIdentifier("field-\(field.name)")
            }
        }
    }
}
