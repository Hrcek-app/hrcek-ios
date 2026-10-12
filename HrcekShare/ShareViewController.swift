import HrcekKit
import SwiftUI
import UIKit

final class ShareViewController: UIViewController {
    private let model = ShareModel(store: KeychainCredentialStore.shared)

    override func viewDidLoad() {
        super.viewDidLoad()
        Log.share.info("Share sheet opened")
        let host = UIHostingController(
            rootView: ShareView(model: model) { [weak self] in self?.finish() })
        addChild(host)
        view.addSubview(host.view)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.didMove(toParent: self)

        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        Task { await model.start(await SharedPage.from(items)) }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
