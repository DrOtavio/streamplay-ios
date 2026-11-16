import Foundation
import AVFoundation
import AVKit
import Combine
import MediaPlayer

@MainActor
final class ChannelViewModel: ObservableObject {
    @Published private(set) var channels: [Channel] = []
    @Published private(set) var currentChannel: Channel?
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false
    @Published private(set) var volume: Float = 1
    @Published var errorMessage: String?

    // A single AVPlayer persists across phone and CarPlay scene changes.
    // When a different channel is chosen only its AVPlayerItem changes.
    let player = AVPlayer()
    private let channelService: any ChannelService
    private var playerObservation: NSKeyValueObservation?
    private var itemObservation: NSKeyValueObservation?
    private var remoteCommands: RemoteCommandController?
    private var interruptionObserver: NSObjectProtocol?

    init(channelService: any ChannelService) {
        self.channelService = channelService
        player.allowsExternalPlayback = true
        player.usesExternalPlaybackWhileExternalScreenIsActive = true
        player.automaticallyWaitsToMinimizeStalling = true
        playerObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isPlaying = player.timeControlStatus == .playing
                self.isLoading = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
                self.updateNowPlaying()
            }
        }
        remoteCommands = RemoteCommandController(model: self)
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue),
                  type == .began else { return }
            Task { @MainActor [weak self] in self?.pause() }
        }
        Task { await reload() }
    }

    deinit {
        playerObservation?.invalidate()
        itemObservation?.invalidate()
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
    }

    func reload() async {
        do {
            channels = try await channelService.loadChannels()
            errorMessage = nil
        } catch {
            errorMessage = "Falha ao carregar canais: \(error.localizedDescription)"
        }
    }

    func select(_ channel: Channel) {
        if currentChannel?.id == channel.id {
            play()
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            errorMessage = "Não foi possível iniciar a sessão de áudio: \(error.localizedDescription)"
            return
        }

        currentChannel = channel
        errorMessage = nil
        itemObservation?.invalidate()
        let item = AVPlayerItem(url: channel.streamUrl)
        itemObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if item.status == .failed {
                    self.errorMessage = item.error?.localizedDescription ?? "Falha de reprodução HLS."
                }
            }
        }
        player.replaceCurrentItem(with: item)
        updateNowPlaying()
        play()
    }

    func play() {
        guard currentChannel != nil else { return }
        player.play()
        isPlaying = true
        updateNowPlaying()
    }

    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlaying()
    }

    func togglePlayback() {
        isPlaying ? pause() : play()
    }

    func stop() {
        pause()
        player.replaceCurrentItem(with: nil)
        currentChannel = nil
        itemObservation?.invalidate()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func setVolume(_ newValue: Float) {
        volume = max(0, min(1, newValue))
        // Remote AirPlay/CarPlay volume is controlled by the route/vehicle.
        player.volume = volume
    }

    func updateNowPlaying() {
        guard let currentChannel else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: currentChannel.name,
            MPMediaItemPropertyArtist: "StreamPlay • Live",
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
    }
}
