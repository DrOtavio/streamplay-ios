import Foundation
import UIKit
import CarPlay
import AVKit
import CoreMedia

/// Standard CarPlay scenes are CPTemplate-only. They cannot host a custom UIViewController.
/// For approved VIDEO apps on iOS 27, playbackConfiguration(.video) + an
/// AirPlay-capable AVPlayer lets CarPlay own the parked-video presentation.
/// For approved AUDIO apps, CPNowPlayingTemplate supplies system playback UI.
@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private weak var interfaceController: CPInterfaceController?
    private let model = AppServices.shared.viewModel
    private var sessionConfiguration: CPSessionConfiguration?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        sessionConfiguration = CPSessionConfiguration(delegate: self)
        let mode = CarPlayMode.configured
        if #available(iOS 27.0, *) {
            let supportsVideo = sessionConfiguration?.supportsVideoPlayback ?? false
            NSLog("StreamPlay CarPlay connected: mode=%@, video-supported=%@", mode.rawValue, supportsVideo ? "yes" : "no")
        } else {
            NSLog("StreamPlay CarPlay connected: mode=%@, legacy audio UI", mode.rawValue)
        }
        // Note: this logs vehicle SUPPORT, not current parked-video availability.
        Task { [weak self] in
            guard let self else { return }
            await model.reload()
            self.installRootTemplate()
        }
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        sessionConfiguration = nil
        // The shared AVPlayer is intentionally kept alive when CarPlay disconnects.
        // Playback may be continued on iPhone or another AirPlay route.
    }

    private func installRootTemplate() {
        guard let interfaceController else { return }

        let home = makeList(title: "Canais", channels: model.channels)
        home.tabTitle = "Home"
        home.tabImage = UIImage(systemName: "house.fill")

        // CPSearchTemplate is reserved for navigation; for media apps, use
        // browsable categorized lists rather than an unsupported custom keyboard.
        let search = makeList(title: "Explorar canais", channels: model.channels.sorted { $0.name < $1.name })
        search.tabTitle = "Search"
        search.tabImage = UIImage(systemName: "magnifyingglass")

        let settings = makeSettings()
        settings.tabTitle = "Settings"
        settings.tabImage = UIImage(systemName: "gearshape.fill")

        let tabs = CPTabBarTemplate(templates: [home, search, settings])
        interfaceController.setRootTemplate(tabs, animated: false) { success, error in
            if !success { NSLog("CarPlay root error: %@", String(describing: error)) }
        }
    }

    private func makeList(title: String, channels: [Channel]) -> CPListTemplate {
        let rows: [CPListItem] = channels.map { channel in
            let item = CPListItem(text: channel.name, detailText: channel.description,
                                  image: UIImage(systemName: "play.rectangle.fill"))
            item.isPlaying = model.currentChannel?.id == channel.id && model.isPlaying
            if #available(iOS 27.0, *), CarPlayMode.configured == .video {
                // A hint to the SYSTEM video presentation, not a custom player view.
                item.playbackConfiguration = CPPlaybackConfiguration(
                    preferredPresentation: .video,
                    playbackAction: .play,
                    elapsedTime: .zero,
                    duration: .zero // live stream / unknown duration
                )
            }
            item.handler = { [weak self] _, completion in
                guard let self else { completion(); return }
                self.model.select(channel)
                self.showPlayer(for: channel)
                completion() // CarPlay always requires a completion callback.
            }
            return item
        }
        return CPListTemplate(title: title, sections: [CPListSection(items: rows)])
    }

    private func showPlayer(for channel: Channel) {
        guard let interfaceController else { return }
        // With preferredPresentation=.video CarPlay automatically presents its
        // system video view when the route/policy allows it. Pushing a new list
        // here could obscure that view. The car owns the parked-video UI.
        if #available(iOS 27.0, *),
           CarPlayMode.configured == .video,
           sessionConfiguration?.supportsVideoPlayback == true {
            NSLog("CarPlay video item selected: %@; system controls presentation", channel.name)
            return
        }

        // Audio mode (including video-unavailable fallback) uses only a CPTemplate.
        // Requires Apple's managed CarPlay entitlement; sideloading is not sufficient.
        interfaceController.pushTemplate(CPNowPlayingTemplate.shared, animated: true) { success, error in
            if !success { NSLog("CarPlay Now Playing error: %@", String(describing: error)) }
        }
    }

    private func makeSettings() -> CPListTemplate {
        let mode = CPListItem(
            text: "Modo CarPlay: \(CarPlayMode.configured.rawValue)",
            detailText: CarPlayMode.configured == .video ? "Vídeo quando estacionado e autorizado" : "Áudio com controles do sistema"
        )
        mode.isEnabled = false
        let playPause = CPListItem(text: "Reproduzir / Pausar", detailText: "Controle do canal atual")
        playPause.handler = { [weak self] _, done in self?.model.togglePlayback(); done() }
        let stop = CPListItem(text: "Parar", detailText: "Encerra o canal atual")
        stop.handler = { [weak self] _, done in self?.model.stop(); done() }
        return CPListTemplate(title: "Settings", sections: [CPListSection(items: [mode, playPause, stop])])
    }
}

extension CarPlaySceneDelegate: CPSessionConfigurationDelegate {
    func sessionConfiguration(_ sessionConfiguration: CPSessionConfiguration,
                              contentStyleChanged contentStyle: CPContentStyle) {
        // Native templates automatically respond to dark/light styling.
    }

    func sessionConfiguration(_ sessionConfiguration: CPSessionConfiguration,
                              limitedUserInterfacesChanged limitedUserInterfaces: CPLimitableUserInterface) {
        // CarPlay itself enforces input/list limitations while driving.
    }
}
