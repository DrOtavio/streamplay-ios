import Foundation

protocol ChannelService {
    func loadChannels() async throws -> [Channel]
}

/// Only clear, publicly documented examples; not a list of commercial TV channels.
struct MockChannelService: ChannelService {
    func loadChannels() async throws -> [Channel] {
        [
            Channel(id: "demo-apple", name: "Apple HLS", streamUrl: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!, category: "Demonstração", description: "Vídeo HLS de teste"),
            Channel(id: "demo-mux", name: "Mux HLS", streamUrl: URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")!, category: "Demonstração", description: "Vídeo HLS de teste"),
            Channel(id: "demo-mp4", name: "MP4 de teste", streamUrl: URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!, category: "Demonstração", description: "Arquivo MP4 público para teste de decodificação")
        ]
    }
}

enum PlaylistImportError: LocalizedError {
    case invalidAddress, invalidFormat, emptyPlaylist, tooLarge

    var errorDescription: String? {
        switch self {
        case .invalidAddress: return "Informe uma URL HTTP/HTTPS válida."
        case .invalidFormat: return "Arquivo não é uma lista M3U/M3U8 válida."
        case .emptyPlaylist: return "Nenhum canal com URL reproduzível foi encontrado."
        case .tooLarge: return "Arquivo excede o limite de 15 MB."
        }
    }
}

/// Parses standard #EXTINF entries with tvg-logo and group-title metadata.
/// An HLS master playlist (#EXT-X-...) is a *single* stream, not a channel list.
struct M3UParser {
    static let maxBytes = 15 * 1024 * 1024

    static func parse(_ data: Data, playlistID: String, baseURL: URL? = nil) throws -> [Channel] {
        guard data.count <= maxBytes else { throw PlaylistImportError.tooLarge }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw PlaylistImportError.invalidFormat
        }
        return try parse(text, playlistID: playlistID, baseURL: baseURL)
    }

    static func parse(_ text: String, playlistID: String, baseURL: URL? = nil) throws -> [Channel] {
        let lines = text.components(separatedBy: .newlines)
        guard lines.contains(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("#EXTM3U") || $0.trimmingCharacters(in: .whitespaces).hasPrefix("#EXTINF") || $0.trimmingCharacters(in: .whitespaces).hasPrefix("#EXT-X-") }) else {
            throw PlaylistImportError.invalidFormat
        }
        if lines.contains(where: { $0.hasPrefix("#EXT-X-") }) {
            guard let baseURL else { throw PlaylistImportError.invalidFormat }
            return [Channel(id: UUID().uuidString, name: baseURL.deletingPathExtension().lastPathComponent,
                            streamUrl: baseURL, category: "HLS", playlistID: playlistID)]
        }
        var result: [Channel] = []
        var pendingName: String?
        var pendingLogo: URL?
        var pendingCategory = "Outros"

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("#EXTINF:") {
                let title = line.range(of: ",", options: .backwards).map { String(line[$0.upperBound...]) }
                pendingName = title?.trimmingCharacters(in: .whitespacesAndNewlines)
                let logo = attribute("tvg-logo", from: line)
                pendingLogo = logo.flatMap(URL.init(string:))
                pendingCategory = attribute("group-title", from: line) ?? "Outros"
            } else if !line.isEmpty && !line.hasPrefix("#") {
                let resolved = URL(string: line, relativeTo: baseURL)?.absoluteURL
                if let url = resolved, ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
                    let name = (pendingName?.isEmpty == false) ? pendingName! : (url.host ?? "Canal")
                    result.append(Channel(id: "\(playlistID)-\(result.count)", name: name, streamUrl: url,
                                          logoUrl: pendingLogo, category: pendingCategory,
                                          description: "Lista IPTV", playlistID: playlistID))
                }
                pendingName = nil
                pendingLogo = nil
                pendingCategory = "Outros"
            }
        }
        guard !result.isEmpty else { throw PlaylistImportError.emptyPlaylist }
        return result
    }

    private static func attribute(_ name: String, from line: String) -> String? {
        let pattern = NSRegularExpression.escapedPattern(for: name) + "=\\\"([^\\\"]*)\\\""
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = expression.firstMatch(in: line, range: range),
              let valueRange = Range(match.range(at: 1), in: line) else { return nil }
        let result = String(line[valueRange]).trimmingCharacters(in: .whitespaces)
        return result.isEmpty ? nil : result
    }
}
