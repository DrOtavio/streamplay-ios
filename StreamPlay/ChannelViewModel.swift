import Foundation
import AVFoundation
import AVKit
import Combine
import MediaPlayer
import CoreMedia

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
    @Published private(set) var recentIDs: [String] = []
    @Published private(set) var videoCodec = "Nenhum vídeo em reprodução"
    @Published private(set) var playbackStatus = "Selecione um canal"
    @Published private(set) var playbackFailure: String?
    @Published private(set) var playbackDiagnostic = ""

    var diagnosticReport: String {
        // Do not copy the full IPTV URL: query strings often contain credentials.
        "Canal: \(currentChannel?.name ?? "Nenhum")\nEstado: \(playbackStatus)\nCodec: \(videoCodec)\n\(playbackDiagnostic)\nFalha: \(playbackFailure ?? "não informada")"
    }
    @Published var quality: PlaybackQuality = .automatic {
        didSet {
            UserDefaults.standard.set(quality.rawValue, forKey: Keys.quality)
            configureQuality(for: player.currentItem)
        }
    }

    let player = AVPlayer()
    private let channelService: any ChannelService
    private var demoChannels: [Channel] = []
    private var imported: [Channel] = []
    private var playerObservation: NSKeyValueObservation?
    private var itemObservation: NSKeyValueObservation?
    private var remoteCommands: RemoteCommandController?
    private var interruptionObserver: NSObjectProtocol?
    private var streamObservers: [NSObjectProtocol] = []
    private var startupCheck: Task<Void, Never>?
    private var selectionVersion = 0

    private enum Keys {
        static let channels = "streamplay.v4.importedChannels"
        static let sources = "streamplay.v4.sources"
        static let favorites = "streamplay.v4.favorites"
        static let recent = "streamplay.v4.recentChannels"
        static let quality = "streamplay.v4.playbackQuality"
    }

    init(channelService: any ChannelService) {
        self.channelService = channelService
        if let data = UserDefaults.standard.data(forKey: Keys.channels),
           let channels = try? JSONDecoder().decode([Channel].self, from: data) { imported = channels }
        if let data = UserDefaults.standard.data(forKey: Keys.sources),
           let saved = try? JSONDecoder().decode([PlaylistSource].self, from: data) { sources = saved }
        if let saved = UserDefaults.standard.array(forKey: Keys.favorites) as? [String] { favorites = Set(saved) }
        if let recent = UserDefaults.standard.array(forKey: Keys.recent) as? [String] { recentIDs = Array(recent.prefix(40)) }
        if let saved = UserDefaults.standard.string(forKey: Keys.quality),
           let selected = PlaybackQuality(rawValue: saved) { quality = selected }
        channels = imported
        player.allowsExternalPlayback = true
        // Keep local iPhone video on the iPhone during diagnosis. Do not force
        // external presentation merely because a display might be connected.
        player.usesExternalPlaybackWhileExternalScreenIsActive = false
        player.automaticallyWaitsToMinimizeStalling = true
        playerObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isPlaying = player.timeControlStatus == .playing
                self.isLoading = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
                if self.currentChannel != nil && self.playbackFailure == nil {
                    switch player.timeControlStatus {
                    case .playing:
                        self.playbackStatus = "Reproduzindo"
                    case .waitingToPlayAtSpecifiedRate:
                        if !self.playbackStatus.contains("18 segundos") {
                            self.playbackStatus = "Aguardando dados do servidor…"
                        }
                    case .paused:
                        if !self.isLoading { self.playbackStatus = "Pausado" }
                    @unknown default: break
                    }
                }
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
        startupCheck?.cancel()
        streamObservers.forEach { NotificationCenter.default.removeObserver($0) }
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

    var recentChannels: [Channel] {
        recentIDs.compactMap { id in channels.first(where: { $0.id == id }) }
    }

    func sourceName(for channel: Channel) -> String {
        guard let sourceID = channel.playlistID else { return "Demonstração" }
        return sources.first(where: { $0.id == sourceID })?.name ?? "Lista IPTV"
    }

    private func configureQuality(for item: AVPlayerItem?) {
        // These knobs influence HLS adaptive playback on the iPhone. They do not
        // transcode video or create an unauthorized CarPlay video session.
        item?.preferredPeakBitRate = quality.peakBitRate
        item?.preferredMaximumResolution = quality.maximumResolution
    }

    private func remember(_ channel: Channel) {
        recentIDs.removeAll(where: { $0 == channel.id })
        recentIDs.insert(channel.id, at: 0)
        recentIDs = Array(recentIDs.prefix(40))
        UserDefaults.standard.set(recentIDs, forKey: Keys.recent)
    }

    private func inspectCodec(of item: AVPlayerItem, channelID: String) {
        // HLS manifests can advertise multiple codecs. This is best-effort
        // inspection of the video track available to AVFoundation.
        Task { [weak self] in
            do {
                guard let track = try await item.asset.loadTracks(withMediaType: .video).first,
                      let description = try await track.load(.formatDescriptions).first else {
                    if self?.currentChannel?.id == channelID { self?.videoCodec = "Não identificado" }
                    return
                }
                let subtype = CMFormatDescriptionGetMediaSubType(description)
                let codec: String
                switch subtype {
                case kCMVideoCodecType_H264: codec = "H.264 / AVC"
                case kCMVideoCodecType_HEVC: codec = "H.265 / HEVC"
                default:
                    let bytes: [UInt8] = [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: subtype >> $0) }
                    codec = String(bytes: bytes, encoding: .ascii) ?? "Outro codec"
                }
                guard self?.currentChannel?.id == channelID else { return }
                self?.videoCodec = codec
            } catch {
                guard self?.currentChannel?.id == channelID else { return }
                self?.videoCodec = "Não identificado"
            }
        }
    }

    private func saveLibrary() {
        if let data = try? JSONEncoder().encode(imported) { UserDefaults.standard.set(data, forKey: Keys.channels) }
        if let data = try? JSONEncoder().encode(sources) { UserDefaults.standard.set(data, forKey: Keys.sources) }
    }

    func select(_ channel: Channel) {
        // Failed items cannot be repaired by calling play() again.
        if currentChannel?.id == channel.id && playbackFailure == nil && player.currentItem?.status != .failed {
            play()
            return
        }
        startChannel(channel)
    }

    func retry() {
        guard let channel = currentChannel else { return }
        startChannel(channel)
    }

    private func startChannel(_ channel: Channel) {
        selectionVersion += 1
        let generation = selectionVersion
        startupCheck?.cancel()
        streamObservers.forEach { NotificationCenter.default.removeObserver($0) }
        streamObservers.removeAll()
        itemObservation?.invalidate()

        do {
            // AirPlay is implicit for the playback category; .allowAirPlay is valid
            // only with .playAndRecord and causes OSStatus -50 here.
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            playbackStatus = "Falha na sessão de áudio"
            playbackFailure = "Sessão de áudio: \(redact(error.localizedDescription))"
            playbackDiagnostic = "Não foi possível iniciar AVAudioSession"
            return
        }

        currentChannel = channel
        remember(channel)
        videoCodec = "Detectando…"
        playbackStatus = "Abrindo canal…"
        playbackFailure = nil
        isPlaying = false
        isLoading = true
        errorMessage = nil
        let kind = channel.streamUrl.pathExtension.isEmpty ? "sem extensão" : channel.streamUrl.pathExtension.lowercased()
        playbackDiagnostic = "Protocolo: \(channel.streamUrl.scheme?.uppercased() ?? "?") • Host: \(channel.streamUrl.host ?? "desconhecido") • Extensão: \(kind)"

        let item = AVPlayerItem(url: channel.streamUrl)
        configureQuality(for: item)
        inspectCodec(of: item, channelID: channel.id)
        itemObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] observedItem, _ in
            Task { @MainActor [weak self] in
                guard let self, self.selectionVersion == generation else { return }
                switch observedItem.status {
                case .readyToPlay:
                    if self.playbackFailure == nil { self.playbackStatus = "Fonte pronta • aguardando quadros…" }
                case .failed:
                    self.reportFailure(observedItem.error, item: observedItem)
                case .unknown: break
                @unknown default: break
                }
            }
        }

        let center = NotificationCenter.default
        streamObservers.append(center.addObserver(forName: AVPlayerItem.newErrorLogEntryNotification, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.selectionVersion == generation else { return }
                if let event = item.errorLog()?.events.last {
                    self.playbackDiagnostic += "\nStream HTTP \(event.errorStatusCode) • \(event.errorDomain): \(self.redact(event.errorComment ?? "sem detalhe"))"
                    if self.playbackDiagnostic.count > 2400 { self.playbackDiagnostic = String(self.playbackDiagnostic.suffix(2400)) }
                }
            }
        })
        streamObservers.append(center.addObserver(forName: AVPlayerItem.failedToPlayToEndTimeNotification, object: item, queue: .main) { [weak self] event in
            let error = event.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            Task { @MainActor [weak self] in
                guard let self, self.selectionVersion == generation else { return }
                self.reportFailure(error, item: item)
            }
        })
        streamObservers.append(center.addObserver(forName: AVPlayerItem.playbackStalledNotification, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.selectionVersion == generation else { return }
                if self.playbackFailure == nil { self.playbackStatus = "Stream travou: aguardando novos dados…" }
            }
        })
        player.replaceCurrentItem(with: item)
        updateNowPlaying()
        play()

        // A timed check catches streams that stay black without generating an
        // AVPlayerItem error. It reports symptoms, not an invented diagnosis.
        startupCheck = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 18_000_000_000)
            guard !Task.isCancelled, let self, self.selectionVersion == generation else { return }
            if item.status == .failed { self.reportFailure(item.error, item: item); return }
            if self.player.timeControlStatus != .playing {
                self.playbackStatus = "Sem reprodução após 18 segundos"
                self.playbackFailure = "O canal não iniciou. Veja o diagnóstico ou teste um canal de demonstração."
            } else if item.presentationSize.width <= 0 || item.presentationSize.height <= 0 {
                self.playbackDiagnostic += "\nAVPlayer iniciou, mas a fonte não informou quadros de vídeo (resolução 0×0)."
                self.playbackStatus = "Reproduzindo sem vídeo detectado"
            }
        }
    }

    private func reportFailure(_ error: Error?, item: AVPlayerItem) {
        let reason = redact(error?.localizedDescription ?? item.error?.localizedDescription ?? "Erro desconhecido do decodificador ou servidor")
        let code = (error ?? item.error).map { "\(($0 as NSError).domain) [\(($0 as NSError).code)]" } ?? ""
        playbackStatus = "Erro ao reproduzir"
        playbackFailure = reason
        playbackDiagnostic += "\nFalha: \(code) \(reason)"
        if let last = item.errorLog()?.events.last {
            playbackDiagnostic += "\nHTTP \(last.errorStatusCode): \(last.errorDomain)"
        }
        isLoading = false
        isPlaying = false
    }

    private func redact(_ value: String) -> String {
        // Hide token-bearing links that a framework or server may place in error messages.
        guard let regex = try? NSRegularExpression(pattern: #"https?://[^\s<>]+"#, options: [.caseInsensitive]) else { return value }
        return regex.stringByReplacingMatches(in: value, range: NSRange(value.startIndex..<value.endIndex, in: value), withTemplate: "[URL omitida]")
    }

    func play() {
        guard currentChannel != nil else { return }
        if playbackFailure != nil { retry(); return }
        player.play()
        // AVPlayer's timeControlStatus observer is the source of truth for isPlaying.
        updateNowPlaying()
    }
    func pause() { player.pause(); isPlaying = false; updateNowPlaying() }
    func togglePlayback() { isPlaying ? pause() : play() }
    func stop() {
        pause()
        selectionVersion += 1
        startupCheck?.cancel()
        streamObservers.forEach { NotificationCenter.default.removeObserver($0) }
        streamObservers.removeAll()
        itemObservation?.invalidate()
        player.replaceCurrentItem(with: nil)
        currentChannel = nil
        videoCodec = "Nenhum vídeo em reprodução"
        playbackStatus = "Parado"
        playbackFailure = nil
        playbackDiagnostic = ""
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
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
