import Foundation
import MediaPlayer

/// MediaPlayer supplies system-standard buttons to headphones, lock screen,
/// supported CarPlay Now Playing screens, and external controls.
@MainActor
final class RemoteCommandController {
    private weak var model: ChannelViewModel?
    private let commandCenter = MPRemoteCommandCenter.shared()
    private var tokens: [Any] = []

    init(model: ChannelViewModel) {
        self.model = model
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        // Streams in this demo behave as live content. Never show skip controls
        // that pretend to work; enable and implement seeking only for VOD items.
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false

        tokens.append(commandCenter.playCommand.addTarget { [weak model] _ in
            Task { @MainActor in model?.play() }
            return .success
        })
        tokens.append(commandCenter.pauseCommand.addTarget { [weak model] _ in
            Task { @MainActor in model?.pause() }
            return .success
        })
        tokens.append(commandCenter.togglePlayPauseCommand.addTarget { [weak model] _ in
            Task { @MainActor in model?.togglePlayback() }
            return .success
        })
    }

    deinit {
        for token in tokens {
            commandCenter.playCommand.removeTarget(token)
            commandCenter.pauseCommand.removeTarget(token)
            commandCenter.togglePlayPauseCommand.removeTarget(token)
        }
    }
}
