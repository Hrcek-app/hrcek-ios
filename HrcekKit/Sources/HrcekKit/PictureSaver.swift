import Foundation

/// Saves an entry with what was chosen for its picture. A picture never
/// costs the entry: when it fails, the entry is saved without it and the
/// reason is answered.
struct PictureSaver {
    let service: EntryService
    let pages: PageAccess

    func save(_ request: EntryIn, choice: PictureChoice) async throws -> (
        created: Bool, trouble: String?
    ) {
        var bytes: PictureBytes?
        var request = request
        if case .address(let url) = choice {
            bytes = await pages.bytes(url)
            // Leaving image_url out keeps the picture as it is, so it is
            // given only when there are no bytes to upload instead.
            if bytes == nil { request = request.with(imageUrl: url.absoluteString) }
        }
        let entry: EntryOut
        let created: Bool
        do {
            (entry, created) = try await service.save(request)
        } catch let error as APIError
            where request.imageUrl != nil && error.code?.hasPrefix("HRC-IMAGE-") == true
        {
            // The server fetches image_url inside the save, so an address it
            // will not go to refuses the whole entry. Once more without it.
            (_, created) = try await service.save(request.with(imageUrl: nil))
            return (created, Self.trouble(error))
        }
        do {
            switch (choice, bytes) {
            case (.remove, _) where entry.image != nil:
                try await service.removePicture(from: entry.id)
            case (.address, let bytes?):
                try await service.upload(bytes, to: entry.id)
            default:
                break
            }
            return (created, nil)
        } catch {
            return (created, Self.trouble(error))
        }
    }

    static func trouble(_ error: any Error) -> String {
        Log.share.notice("Picture failed: \(String(describing: error), privacy: .public)")
        let reason = UserFacingError.message(for: error)
        return L10n.string("The entry was saved, but the picture could not be attached: \(reason)")
    }
}

extension EntryIn {
    func with(imageUrl: String?) -> EntryIn {
        EntryIn(
            url: url, title: title, notes: notes, tags: tags, fields: fields, imageUrl: imageUrl)
    }
}
