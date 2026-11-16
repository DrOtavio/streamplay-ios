import Foundation
import AVFoundation
import AVKit
import Combine
import MediaPlayer

@MainActor
final class ChannelViewModel: ObservableObject {
    @Published private(set) var channels: [Channel] = []
    @Published private(set) var sources: [PlaylistSource] = []
    @Published private(set) var favorites: Set<String> = []
    @Published private(set) var currentChannel: Channel?
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false
    @Published private(set) var volume: Float = 1
    @Published var errorMessage: String?
    @Published var importMessage: String?

    let player = AVPlayer()
    private let channelService: any ChannelService
    private var demoChannels: [Channel] = []
    private var imported: [Channel] = []
    private var playerObservation: NSKeyValueObservation?
    private var itemObservation: NSKeyValueObservation?
    private var remoteCommands: RemoteCommandController?
    private var interruptionObserver: NSObjectProtocol?

    private enum Keys {
        static let channels = "streamplay.v4.importedChannels"
        static let sources = "streamplay.v4.sources"
        static let favorites = "streamplay.v4.favorites"
    }

    init(channelService: any ChannelService) {
        self.channelService = channelService
        if let data = UserDefaults.standard.data(forKey: Keys.channels),
           let channels = try? JSONDecoder().decode([Channel].self, from: data) { imported = channels }
        if let data = UserDefaults.standard.data(forKey: Keys.sources),
           let saved = try? JSONDecoder().decode([PlaylistSource].self, from: data) { sources = saved }
        if let saved = UserDefaults.standard.array(forKey: Keys.favorites) as? [String] { favorites = Set(saved) }
        channels = imported
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
        interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification,
                                                                         object: AVAudioSession.sharedInstance(), queue: .main) { [weak self] notification in
            guard let value = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: value) == .began else { return }
            Task { @MainActor [weak self] in self?.pause() }
        }
        Task { await reload() }
    }

    deinit {
        playerObservation?.invalidate()
        itemObservation?.invalidate()
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
    }

    func reload() async {
        do {
            demoChannels = try await channelService.loadChannels()
            rebuild()
        } catch { errorMessage = "Falha nos canais de teste: \(error.localizedDescription)" }
    }

    private func rebuild() { channels = imported + demoChannels }

    func importURL(_ enteredURL: String) async {
        let raw = enteredURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: raw), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            errorMessage = PlaylistImportError.invalidAddress.localizedDescription
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard data.count <= M3UParser.maxBytes else { throw PlaylistImportError.tooLarge }
            try importData(data, title: url.host ?? "Lista IPTV", source: url.absoluteString, baseURL: url)
        } catch { errorMessage = "Importação falhou: \(error.localizedDescription)" }
    }

    func importFile(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            try importData(data, title: url.deletingPathExtension().lastPathComponent,
                           source: url.lastPathComponent, baseURL: nil)
        } catch { errorMessage = "Não foi possível ler a lista: \(error.localizedDescription)" }
    }

    private func importData(_ data: Data, title: String, source: String, baseURL: URL?) throws {
        let existing = sources.first(where: { $0.source == source })
        let id = existing?.id ?? UUID().uuidString
        let parsed = try M3UParser.parse(data, playlistID: id, baseURL: baseURL)
        imported.removeAll { $0.playlistID == id }
        imported.append(contentsOf: parsed)
        sources.removeAll { $0.id == id }
        sources.insert(PlaylistSource(id: id, name: title, source: source,
                                      channelCount: parsed.count, importedAt: Date()), at: 0)
        saveLibrary()
        rebuild()
        importMessage = "\(parsed.count) canais importados de \(title)."
        errorMessage = nil
    }

    func removeSource(_ source: PlaylistSource) {
        sources.removeAll { $0.id == source.id }
        imported.removeAll { $0.playlistID == source.id }
        saveLibrary()
        rebuild()
    }

    func toggleFavorite(_ channel: Channel) {
        if favorites.contains(channel.id) { favorites.remove(channel.id) }
        else { favorites.insert(channel.id) }
        UserDefaults.standard.set(Array(favorites), forKey: Keys.favorites)
    }

    func isFavorite(_ channel: Channel) -> Bool { favorites.contains(channel.id) }

    private func saveLibrary() {
        if let data = try? JSONEncoder().encode(imported) { UserDefaults.standard.set(data, forKey: Keys.channels) }
        if let data = try? JSONEncoder().encode(sources) { UserDefaults.standard.set(data, forKey: Keys.sources) }
    }

    func select(_ channel: Channel) {
        if currentChannel?.id == channel.id { play(); return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            errorMessage = "Sessão de áudio indisponível: \(error.localizedDescription)"
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
                    self.errorMessage = item.error?.localizedDescription ?? "Falha ao reproduzir o stream."
                }
            }
        }
        player.replaceCurrentItem(with: item)
        updateNowPlaying()
        play()
    }

    func play() { guard currentChannel != nil else { return }; player.play(); isPlaying = true; updateNowPlaying() }
    func pause() { player.pause(); isPlaying = false; updateNowPlaying() }
    func togglePlayback() { isPlaying ? pause() : play() }
    func stop() {
        pause(); player.replaceCurrentItem(with: nil); currentChannel = nil
        itemObservation?.invalidate(); MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    func setVolume(_ newValue: Float) {
        volume = min(1, max(0, newValue)); player.volume = volume
    }
    func updateNowPlaying() {
        guard let channel = currentChannel else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: channel.name,
            MPMediaItemPropertyArtist: "StreamPlay • IPTV",
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
    }
}
