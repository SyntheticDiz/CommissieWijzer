#if os(iOS)
import SwiftUI
import UIKit

/// Keeps native presentations attached to the window that owns the initiating UI.
@MainActor
final class AppPresentationContext: ObservableObject, Identifiable {
    let id = UUID()
    private weak var window: UIWindow?

    func attach(_ window: UIWindow?) {
        self.window = window
    }

    var foregroundWindow: UIWindow? {
        guard let window,
              window.windowScene?.activationState == .foregroundActive,
              !window.isHidden,
              window.rootViewController != nil else { return nil }
        return window
    }

    var foregroundPresenter: UIViewController? {
        guard let window = foregroundWindow, var presenter = window.rootViewController else { return nil }
        while let presented = presenter.presentedViewController { presenter = presented }
        guard presenter.viewIfLoaded?.window === window else { return nil }
        return presenter
    }
}

private struct AppPresentationContextKey: EnvironmentKey {
    static let defaultValue: AppPresentationContext? = nil
}

extension EnvironmentValues {
    var appPresentationContext: AppPresentationContext? {
        get { self[AppPresentationContextKey.self] }
        set { self[AppPresentationContextKey.self] = newValue }
    }
}

private final class AppPresentationAnchorView: UIView {
    var context: AppPresentationContext?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        context?.attach(window)
    }
}

private struct AppPresentationContextAnchor: UIViewRepresentable {
    let context: AppPresentationContext

    func makeUIView(context _: Context) -> AppPresentationAnchorView {
        let view = AppPresentationAnchorView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.context = context
        return view
    }

    func updateUIView(_ view: AppPresentationAnchorView, context _: Context) {
        if view.context !== context {
            view.context?.attach(nil)
            view.context = context
            view.context?.attach(view.window)
        }
    }

    static func dismantleUIView(_ view: AppPresentationAnchorView, coordinator: ()) {
        view.context?.attach(nil)
    }
}

struct AppPresentationContextHost: ViewModifier {
    @StateObject private var context = AppPresentationContext()

    func body(content: Content) -> some View {
        content
            .environment(\.appPresentationContext, context)
            .overlay {
                AppPresentationContextAnchor(context: context)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }
}

extension View {
    /// Install once on each window's root content, for example on `SimpleView`.
    func appPresentationContextHost() -> some View {
        modifier(AppPresentationContextHost())
    }
}
#endif
