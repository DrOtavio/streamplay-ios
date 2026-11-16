import Foundation

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
