#if os(iOS)
import Foundation
import SafariServices
import UIKit

/// Presents the provider's normal authorization page in Safari's system browser
/// sheet. The page and cookies remain owned by SafariServices; the app only
/// receives the separately validated loopback callback.
@MainActor
enum iPadAuthBrowser {
    private static var sessions: [UUID: BrowserSession] = [:]

    static func present(_ url: URL, context: AppPresentationContext? = nil, onUserDismiss: @escaping () -> Void) throws -> BrowserSession {
        let presenter: UIViewController?
        if let context {
            presenter = context.foregroundPresenter
        } else if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
                  let window = scene.windows.first(where: \.isKeyWindow), var top = window.rootViewController {
            while let presented = top.presentedViewController { top = presented }
            presenter = top.viewIfLoaded?.window === window ? top : nil
        } else { presenter = nil }
        guard let presenter else { throw AccountBrowserError.noForegroundPresenter }

        let session = BrowserSession(url: url, onUserDismiss: onUserDismiss)
        sessions[session.id] = session
        presenter.present(session.controller, animated: true)
        return session
    }

    fileprivate static func finish(_ session: BrowserSession) {
        sessions.removeValue(forKey: session.id)
    }

    @MainActor
    final class BrowserSession: NSObject, @preconcurrency SFSafariViewControllerDelegate {
        fileprivate let id = UUID()
        fileprivate let controller: SFSafariViewController
        private let onUserDismiss: () -> Void

        fileprivate init(url: URL, onUserDismiss: @escaping () -> Void) {
            self.onUserDismiss = onUserDismiss
            controller = SFSafariViewController(url: url)
            super.init()
            controller.delegate = self
        }

        @MainActor
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            onUserDismiss()
            iPadAuthBrowser.finish(self)
        }

        func dismiss() {
            guard controller.presentingViewController != nil else {
                iPadAuthBrowser.finish(self)
                return
            }
            controller.dismiss(animated: true) { iPadAuthBrowser.finish(self) }
        }
    }

    private enum AccountBrowserError: LocalizedError {
        case noForegroundPresenter
        var errorDescription: String? { "De beveiligde aanmeldpagina kan niet worden geopend. Keer terug naar CommissieWijzer en probeer opnieuw." }
    }
}
#endif
