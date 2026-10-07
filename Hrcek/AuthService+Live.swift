import HrcekKit
import UIKit

extension AuthService {
    @MainActor
    static func live() -> AuthService {
        AuthService(store: KeychainCredentialStore.shared, deviceName: UIDevice.current.name)
    }
}
