import UIKit

/// A UIKit entry point is deliberate: UIKit owns both UIScene delegates.
/// SwiftUI still renders every iPhone screen via UIHostingController.
@main
@MainActor
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        _ = AppServices.shared
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // The role is supplied by iOS, not by an attempt to force CarPlay to open.
        // Prefer the strongly typed UIKit role; raw string comparisons are brittle.
        // The custom CarPlay window role is not exposed as a Swift enum case.
        // It is only delivered if the signed app has a matching Apple entitlement.
        if connectingSceneSession.role.rawValue == "UIWindowSceneSessionRoleCarPlay" {
            return UISceneConfiguration(name: "CarPlay Window Configuration", sessionRole: connectingSceneSession.role)
        }
        if connectingSceneSession.role == .carTemplateApplication {
            return UISceneConfiguration(
                name: "CarPlay Scene Configuration", sessionRole: .carTemplateApplication
            )
        }
        return UISceneConfiguration(name: "Phone Scene Configuration", sessionRole: .windowApplication)
    }
}

@MainActor
final class AppServices {
    static let shared = AppServices()
    let viewModel: ChannelViewModel
    let browser: BrowserStore
    let car: CarDisplayCoordinator

    private init() {
        viewModel = ChannelViewModel(channelService: MockChannelService())
        browser = BrowserStore()
        car = CarDisplayCoordinator.shared
    }
}
