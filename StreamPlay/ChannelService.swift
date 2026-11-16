import Foundation

protocol ChannelService {
    func loadChannels() async throws -> [Channel]
}

/// Replace this with an authenticated catalog endpoint or a permitted M3U parser.
/// These are public test HLS streams, NOT Globo/SporTV/paid TV channels.
struct MockChannelService: ChannelService {
    func loadChannels() async throws -> [Channel] {
        return [
            Channel(
                id: "apple-bipbop",
                name: "Apple HLS Demo",
                streamUrl: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!,
                category: "Testes",
                description: "Apple HTTP Live Streaming sample"
            ),
            Channel(
                id: "mux-test",
                name: "Mux HLS Demo",
                streamUrl: URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")!,
                category: "Testes",
                description: "Mux public test stream"
            ),
            Channel(
                id: "mux-test-2",
                name: "Mux Test Pattern",
                streamUrl: URL(string: "https://test-streams.mux.dev/test_001/stream.m3u8")!,
                category: "Testes",
                description: "Public HLS compatibility test"
            )
        ]
    }
}
