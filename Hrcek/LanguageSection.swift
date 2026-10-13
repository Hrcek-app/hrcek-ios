import HrcekKit
import SwiftUI

/// The language the app and the share sheet speak.
struct LanguageSection: View {
    @Environment(LanguageModel.self) private var language

    var body: some View {
        Section {
            Picker(
                "Language",
                selection: Binding(get: { language.choice }, set: { language.choose($0) })
            ) {
                ForEach(language.options, id: \.self) { option in
                    Text(verbatim: option.name).tag(option.tag)
                }
            }
            .accessibilityIdentifier("language")
        } footer: {
            Text("Also the language of the Share sheet and of the server's messages.")
        }
    }
}
