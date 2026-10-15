import Foundation

// Tags, as they are typed.
extension ShareModel {
    /// Adds what was typed as tags, one per comma.
    public func commitTagText() {
        for tag in tagText.split(separator: ",") { draft.addTag(String(tag)) }
        tagText = ""
        suggestions = []
    }

    public func choose(_ suggestion: String) {
        draft.addTag(suggestion)
        tagText = ""
        suggestions = []
    }

    /// Call whenever `tagText` changes; cancelling the call drops it.
    public func updateSuggestions() async {
        let prefix = tagText.trimmingCharacters(in: .whitespaces)
        guard let service, !prefix.isEmpty else {
            suggestions = []
            return
        }
        do {
            try await Task.sleep(for: suggestionDelay)
            let labels = try await service.labels(startingWith: prefix)
            // The person may have typed on, or added the tag, while it was asked.
            guard !Task.isCancelled, tagText.trimmingCharacters(in: .whitespaces) == prefix
            else { return }
            // Offering a tag already there would only invite a duplicate.
            let fresh = labels.filter { label in
                !draft.tags.contains { EntryDraft.same($0, label) }
            }
            suggestions = Array(fresh.prefix(8))
        } catch is CancellationError {
            return
        } catch {
            // Typing on cancels the request, which then fails as a transport error.
            if Task.isCancelled { return }
            // A convenience whose absence explains itself; not worth an error.
            Log.share.notice("No suggestions: \(String(describing: error), privacy: .public)")
            suggestions = []
        }
    }
}
