import Foundation
import CoreGraphics

struct Channel: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let streamUrl: URL
    let logoUrl: URL?
    let category: String
    let description: String
    let playlistID: String?

    init(id: String, name: String, streamUrl: URL, logoUrl: URL? = nil,
         category: String = "Sem categoria", description: String = "Canal IPTV",
         playlistID: String? = nil) {
        self.id = id
        self.name = name
        self.streamUrl = streamUrl
        self.logoUrl = logoUrl
        self.category = category
        self.description = description
        self.playlistID = playlistID
    }
}

struct PlaylistSource: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var source: String
    var channelCount: Int
    var importedAt: Date
}

struct BrowserBookmark: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let url: URL
}

enum CarPlayMode: String {
    case audio, video

    static var configured: Self {
        let mode = Bundle.main.object(forInfoDictionaryKey: "CarPlayMode") as? String
        return Self(rawValue: mode ?? "audio") ?? .audio
    }
}

/// Limits adaptive HLS playback on the phone, not the video stream shown on CarPlay.
enum PlaybackQuality: String, CaseIterable, Identifiable {
    case automatic = "Automática"
    case economy = "Economia de dados"
    case hd = "Até 720p"
    case fullHD = "Até 1080p"

    var id: String { rawValue }
    var peakBitRate: Double {
        switch self {
        case .automatic, .hd, .fullHD: return 0
        case .economy: return 900_000
        }
    }
    var maximumResolution: CGSize {
        switch self {
        case .automatic, .economy: return .zero
        case .hd: return CGSize(width: 1280, height: 720)
        case .fullHD: return CGSize(width: 1920, height: 1080)
        }
    }
}
