import SwiftUI
import UIKit

@MainActor
final class ShareViewController: UIViewController {
    private let model = ShareExtensionModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        let rootView = ShareExtensionRootView(
            model: model,
            onCancel: { [weak self] in
                self?.extensionContext?.cancelRequest(withError: CancellationError())
            },
            onComplete: { [weak self] result in
                switch result {
                case .queued:
                    self?.extensionContext?.completeRequest(returningItems: nil)
                case .openContainingApp(let url):
                    self?.extensionContext?.open(url, completionHandler: nil)
                    self?.extensionContext?.completeRequest(returningItems: nil)
                }
            }
        )
        let host = UIHostingController(rootView: rootView)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)

        Task {
            await model.load(extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? [])
        }
    }
}
