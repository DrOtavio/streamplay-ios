import UIKit
import SwiftUI

/// The phone scene uses SwiftUI; the CarPlay scene uses CPTemplateApplicationSceneDelegate.
@MainActor
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(
            rootView: ContentView(viewModel: AppServices.shared.viewModel)
        )
        self.window = window
        window.makeKeyAndVisible()
    }
}
