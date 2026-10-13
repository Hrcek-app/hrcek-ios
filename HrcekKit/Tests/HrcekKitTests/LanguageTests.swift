import Foundation
import Synchronization
import Testing

@testable import HrcekKit

@Suite struct LanguageTests {
    @Test func aChoiceWins() {
        #expect(L10n.resolve("sl", preferred: ["en-GB"]) == "sl")
    }

    @Test func otherwiseThePhonesFirstLanguageThereIsATranslationFor() {
        #expect(L10n.resolve(nil, preferred: ["sl-SI", "en"]) == "sl")
        #expect(L10n.resolve(nil, preferred: ["de-AT", "sl"]) == "sl")
        #expect(L10n.resolve(nil, preferred: ["en-US", "sl"]) == "en")
    }

    @Test func englishWhenNothingElseFits() {
        #expect(L10n.resolve(nil, preferred: ["de", "fr"]) == "en")
        #expect(L10n.resolve("fr", preferred: []) == "en")
    }

    @Test func speaksTheLanguageAskedFor() {
        let resource: LocalizedStringResource = "Something went wrong. Try again."
        #expect(L10n.string(resource, language: "sl") == "Nekaj je šlo narobe. Poskusite znova.")
        #expect(L10n.string(resource, language: "en") == "Something went wrong. Try again.")
    }
}

@MainActor
@Suite struct LanguageModelTests {
    final class Applied: Sendable {
        let choices = Mutex<[String?]>([])
    }

    struct Fixture {
        let model: LanguageModel
        let store: InMemoryLanguageStore
        let applied: Applied
    }

    func fixture(stored: String? = nil, preferred: [String] = ["en"]) -> Fixture {
        let store = InMemoryLanguageStore(stored)
        let applied = Applied()
        let model = LanguageModel(store: store, preferred: preferred) { choice in
            applied.choices.withLock { $0.append(choice) }
        }
        return Fixture(model: model, store: store, applied: applied)
    }

    @Test func startsWithWhatWasChosenBefore() {
        let fixture = fixture(stored: "sl")
        #expect(fixture.model.choice == "sl")
        #expect(fixture.model.locale.identifier == "sl")
        #expect(fixture.applied.choices.withLock { $0 } == ["sl"])
    }

    @Test func remembersAndAppliesAChoice() throws {
        let fixture = fixture()
        fixture.model.choose("sl")
        #expect(try fixture.store.load() == "sl")
        #expect(fixture.applied.choices.withLock { $0 }.last == "sl")
        fixture.model.choose(nil)
        #expect(try fixture.store.load() == nil)
        #expect(fixture.model.locale.identifier == "en")
    }

    @Test func namesEachLanguageInItself() {
        let model = fixture(preferred: ["sl"]).model
        #expect(model.options.map(\.tag) == [nil, "en", "sl"])
        #expect(model.options.dropFirst().map(\.name) == ["English", "Slovenščina"])
    }

    @Test func saysWhichLanguageAutomaticMeans() {
        let english = fixture(preferred: ["en"]).model
        #expect(english.options.first?.name == "Automatic (English)")
        let slovenian = fixture(preferred: ["sl"]).model
        #expect(slovenian.options.first?.name == "Samodejno (slovenščina)")
    }
}
