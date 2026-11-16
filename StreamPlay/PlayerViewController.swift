import AVKit
import UIKit
import SwiftUI

/// UIKit AVPlayerLayer host for iPhone or other app-owned UIWindow scenes.
/// IMPORTANT: CPInterfaceController.pushTemplate takes CPTemplate, NEVER a UIViewController.
/// This controller cannot be pushed into a standard CarPlay template hierarchy.
final class PlayerViewController: UIViewController {
    private let playerLayer = AVPlayerLayer()
    var player: AVPlayer? {
        didSet { playerLayer.player = player }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        playerLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(playerLayer)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer.frame = view.bounds
    }
}

struct PlayerLayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> PlayerViewController {
        let controller = PlayerViewController()
        controller.player = player
        return controller
    }

    func updateUIViewController(_ controller: PlayerViewController, context: Context) {
        if controller.player !== player { controller.player = player }
    }
}

/// AVRoutePickerView lets the user select a supported AirPlay screen,
/// including CarPlay video-in-car receivers when parked and available.
struct AirPlayRoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.prioritizesVideoDevices = true
        return picker
    }

    func updateUIView(_ view: AVRoutePickerView, context: Context) {}
}
