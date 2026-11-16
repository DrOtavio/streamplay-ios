import UIKit

/// Experimental CarPlay UIWindowScene route documented by Cafari Lite.
/// iOS will NOT connect this scene without a managed entitlement on the signed app.
@MainActor
final class CarDisplayWindowSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        let controller = CarDisplayViewController()
        window.rootViewController = controller
        self.window = window
        window.makeKeyAndVisible()
        CarDisplayCoordinator.shared.connect(controller)
        NSLog("StreamPlay: authorized CarPlay window connected")
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        CarDisplayCoordinator.shared.disconnect()
        window = nil
        NSLog("StreamPlay: CarPlay window disconnected")
    }
}
