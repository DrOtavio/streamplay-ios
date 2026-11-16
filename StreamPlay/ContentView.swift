import SwiftUI
import AVKit

struct ContentView: View {
    @ObservedObject var viewModel: ChannelViewModel
    @State private var searchText = ""

    var body: some View {
        TabView {
            NavigationStack {
                List {
                    if let current = viewModel.currentChannel {
                        Section("Reproduzindo") {
                            NavigationLink {
                                ChannelPlayerView(viewModel: viewModel, channel: current)
                            } label: {
                                Label(current.name, systemImage: "waveform")
                            }
                        }
                    }
                    Section("Todos os canais") {
                        ForEach(viewModel.channels) { channel in
                            NavigationLink {
                                ChannelPlayerView(viewModel: viewModel, channel: channel)
                            } label: {
                                ChannelRow(channel: channel)
                            }
                        }
                    }
                }
                .navigationTitle("StreamPlay")
                .refreshable { await viewModel.reload() }
            }
            .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack {
                List(viewModel.channels.filter {
                    searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
                }) { channel in
                    NavigationLink {
                        ChannelPlayerView(viewModel: viewModel, channel: channel)
                    } label: {
                        ChannelRow(channel: channel)
                    }
                }
                .navigationTitle("Buscar")
                .searchable(text: $searchText, prompt: "Buscar canal")
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }

            NavigationStack {
                Form {
                    Section("Reprodução") {
                        HStack {
                            Text("Volume local")
                            Slider(
                                value: Binding(
                                    get: { Double(viewModel.volume) },
                                    set: { viewModel.setVolume(Float($0)) }
                                ),
                                in: 0...1
                            )
                        }
                        Button("Parar reprodução", role: .destructive) { viewModel.stop() }
                    }
                    Section("CarPlay") {
                        Text("Modo configurado: \(CarPlayMode.configured.rawValue)")
                        Text("Vídeo no carro requer iOS 27, veículo compatível e entitlement aprovado pela Apple. Não há vídeo durante a condução.")
                            .font(.footnote)
                    }
                }
                .navigationTitle("Configurações")
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(.cyan)
        .preferredColorScheme(.dark)
        .alert("Erro", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "Erro desconhecido")
        }
    }
}

private struct ChannelRow: View {
    let channel: Channel

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.cyan.opacity(0.13))
                    .frame(width: 56, height: 48)
                if let logoUrl = channel.logoUrl {
                    AsyncImage(url: logoUrl) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Image(systemName: "play.tv.fill")
                    }
                    .frame(width: 44, height: 36)
                } else {
                    Image(systemName: "play.tv.fill")
                        .foregroundStyle(.cyan)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(channel.name).font(.headline)
                Text(channel.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ChannelPlayerView: View {
    @ObservedObject var viewModel: ChannelViewModel
    let channel: Channel

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: geometry.size.height < 450 ? 10 : 18) {
                    // ScrollView prevents controls being clipped in landscape.
                    VideoPlayer(player: viewModel.player)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .background(.black)
                        .accessibilityLabel("Reprodução de \(channel.name)")
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(channel.name).font(.title3.bold())
                            Text(channel.category).foregroundStyle(.secondary)
                        }
                        Spacer()
                        AirPlayRoutePicker()
                            .frame(width: 44, height: 44)
                    }
                    .padding(.horizontal)
                    HStack(spacing: 30) {
                        Button {
                            viewModel.togglePlayback()
                        } label: {
                            Label(viewModel.isPlaying ? "Pausar" : "Reproduzir",
                                  systemImage: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Parar") { viewModel.stop() }
                            .buttonStyle(.bordered)
                    }
                    if viewModel.isLoading { ProgressView("Carregando stream…") }
                }
                .frame(maxWidth: 960)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Player")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.select(channel) }
    }
}
