import Foundation
import Combine
import CoreGraphics

/// Commands originate from the phone; only an authorized UIWindowScene can render on CarPlay.
@MainActor
final class CarDisplayCoordinator: ObservableObject {
    static let shared = CarDisplayCoordinator()
    enum Mode { case browser, media, standby }
    @Published private(set) var connected = false
    @Published private(set) var mode: Mode = .standby
    @Published private(set) var desiredURL: URL?
    private weak var controller: CarDisplayViewController?

    private init() {}

    func connect(_ controller: CarDisplayViewController) {
        self.controller = controller
        connected = true
        switch mode {
        case .browser: if let desiredURL { controller.showBrowser(desiredURL) }
        case .media: controller.showMedia()
        case .standby: controller.showStandby()
        }
    }
    func disconnect() { controller = nil; connected = false }

    func showBrowser(url: URL) {
        desiredURL = url
        mode = .browser
        controller?.showBrowser(url)
    }
    func followPhoneNavigation(url: URL) {
        guard mode == .browser, desiredURL != url else { return }
        desiredURL = url
        controller?.showBrowser(url)
    }
    func showMedia() { mode = .media; controller?.showMedia() }
    func showStandby() { mode = .standby; controller?.showStandby() }
    func movePointer(dx: CGFloat, dy: CGFloat) { controller?.movePointer(dx: dx, dy: dy) }
    func click() { controller?.click() }
    func scroll(_ amount: CGFloat) { controller?.scroll(amount) }
    func typeText(_ text: String) { controller?.typeText(text) }
}
