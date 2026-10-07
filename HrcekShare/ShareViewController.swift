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
        Task {
            await model.save(await SharedPage.from(items))
            if [.saved, .alreadySaved].contains(model.state) {
                // Long enough to read the confirmation; Done closes sooner.
                try? await Task.sleep(for: .seconds(2))
                finish()
            }
        }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
