import Foundation

struct Channel: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let streamUrl: URL
    let logoUrl: URL?
    let category: String
    let description: String

    init(
        id: String,
        name: String,
        streamUrl: URL,
        logoUrl: URL? = nil,
        category: String = "Demonstração",
        description: String = "Transmissão HLS de demonstração"
    ) {
        self.id = id
        self.name = name
        self.streamUrl = streamUrl
        self.logoUrl = logoUrl
        self.category = category
        self.description = description
    }
}

enum CarPlayMode: String {
    case audio
    case video

    static var configured: Self {
        let key = Bundle.main.object(forInfoDictionaryKey: "CarPlayMode") as? String
        return Self(rawValue: key ?? "audio") ?? .audio
    }
}
