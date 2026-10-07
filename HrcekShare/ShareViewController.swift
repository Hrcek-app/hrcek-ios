import HrcekKit
import SwiftUI
import UIKit

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        Log.share.info("Share sheet opened")
        let host = UIHostingController(rootView: ShareView { [weak self] in self?.finish() })
        addChild(host)
        view.addSubview(host.view)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.didMove(toParent: self)
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
