import SwiftUI
import UIKit
import AVKit
import MapKit
import UniformTypeIdentifiers
import WebKit

private enum Theme {
    static let background = Color(red: 0.025, green: 0.041, blue: 0.037)
    static let panel = Color(red: 0.078, green: 0.105, blue: 0.093)
    static let raised = Color(red: 0.105, green: 0.130, blue: 0.118)
    static let border = Color(red: 0.20, green: 0.25, blue: 0.22)
    static let accent = Color(red: 0.83, green: 1.00, blue: 0.40)
    static let muted = Color(red: 0.60, green: 0.66, blue: 0.62)
}

private enum MainTab: String, CaseIterable {
    case watch = "Assistir", maps = "Mapas", car = "Carro", settings = "Ajustes"
    var symbol: String {
        switch self {
        case .watch: return "play.rectangle.fill"
        case .maps: return "map.fill"
        case .car: return "car.side.fill"
        case .settings: return "slider.horizontal.3"
        }
    }
}

struct ContentView: View {
    @ObservedObject var viewModel: ChannelViewModel
    @ObservedObject private var car = CarDisplayCoordinator.shared
    @State private var selectedTab: MainTab = .watch

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            Group {
                switch selectedTab {
                case .watch: WatchHomeView(viewModel: viewModel)
                case .maps: MapPage()
                case .car: CarHomeView(viewModel: viewModel)
                case .settings: SettingsPage(viewModel: viewModel)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomTabs }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        .alert("Aviso do StreamPlay", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("Entendi") { viewModel.errorMessage = nil }
        } message: { Text(viewModel.errorMessage ?? "Erro") }
    }

    private var bottomTabs: some View {
        HStack(spacing: 5) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                Button { selectedTab = tab } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.symbol).font(.system(size: 23, weight: .semibold))
                        Text(tab.rawValue).font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .foregroundStyle(selectedTab == tab ? Color.black : Theme.muted)
                    .background(selectedTab == tab ? Theme.accent : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.rawValue)
            }
        }
        .padding(6)
        .background(Theme.raised, in: Capsule())
        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 5)
        .background(Theme.background.opacity(0.98))
    }
}

private struct SectionEyebrow: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .tracking(2.6).foregroundStyle(Theme.accent)
    }
}

private struct PageHeading: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionEyebrow(title: subtitle)
            Text(title).font(.system(size: 35, weight: .bold, design: .rounded)).foregroundStyle(.white)
        }
    }
}

private struct FeatureCard: View {
    let name: String
    let detail: String
    let symbol: String
    var selected = false
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(selected ? Color.black : Theme.accent)
                .frame(width: 55, height: 55)
                .background(selected ? Theme.accent : Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))
            Spacer(minLength: 8)
            Text(name).font(.system(size: 23, weight: .semibold, design: .rounded))
                .foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
            Text(detail).font(.system(size: 15)).foregroundStyle(Theme.muted)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 178)
        .padding(18)
        .background(selected ? Theme.raised : Theme.panel, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(selected ? Theme.accent : Theme.border, lineWidth: selected ? 1.5 : 1))
    }
}

private enum CarRoute: Hashable { case browser, media, touchpad, mirroring, maps }

private struct CarHomeView: View {
    @ObservedObject var viewModel: ChannelViewModel
    @ObservedObject private var car = CarDisplayCoordinator.shared
    @ObservedObject private var browser = AppServices.shared.browser

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionEyebrow(title: "Tela do carro")
                        HStack(alignment: .center) {
                            Text("Carro")
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Spacer()
                            HStack(spacing: 7) {
                                Circle().fill(car.connected ? Theme.accent : Theme.muted).frame(width: 7, height: 7)
                                Text(car.connected ? "CONECTADO" : "AGUARDANDO O CARRO")
                                    .font(.system(size: 10, weight: .bold)).tracking(1.5)
                            }
                            .foregroundStyle(car.connected ? Theme.accent : Theme.muted)
                            .padding(.horizontal, 13).padding(.vertical, 13)
                            .background(Theme.panel, in: Capsule())
                            .overlay(Capsule().stroke(Theme.border))
                        }
                    }
                    HStack(spacing: 12) {
                        summaryCard(symbol: "clock", main: "24/7", sub: "Sua biblioteca")
                        summaryCard(symbol: "car.side", main: car.connected ? "Conectado" : "Aguardando", sub: "CarPlay")
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Mostrar na tela do carro")
                            .font(.system(size: 24, weight: .semibold)).foregroundStyle(.white)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 13), GridItem(.flexible(), spacing: 13)], spacing: 13) {
                            NavigationLink(value: CarRoute.mirroring) {
                                FeatureCard(name: "Espelhar o telefone", detail: "Opções de transmissão", symbol: "rectangle.on.rectangle")
                            }
                            NavigationLink(value: CarRoute.browser) {
                                FeatureCard(name: "Navegador", detail: "Sites e pesquisa", symbol: "globe")
                            }
                            NavigationLink(value: CarRoute.media) {
                                FeatureCard(name: "Mídia", detail: "Canais e playlists", symbol: "play.rectangle.fill", selected: true)
                            }
                            NavigationLink(value: CarRoute.maps) {
                                FeatureCard(name: "Mapas", detail: "Explorar no mapa", symbol: "map.fill")
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle.fill").foregroundStyle(Color(red: 0.49, green: 0.78, blue: 1))
                        Text("Exiba conteúdo visual somente quando o veículo estiver estacionado ou em telas exclusivas para passageiros.")
                            .font(.system(size: 14)).foregroundStyle(.white)
                    }
                    .padding(17)
                    .background(Color(red: 0.07, green: 0.12, blue: 0.14), in: RoundedRectangle(cornerRadius: 20))
                    NavigationLink(value: CarRoute.touchpad) {
                        Label("Abrir controle touchpad", systemImage: "hand.draw.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border))
                    }
                }
                .padding(.horizontal, 20).padding(.top, 25).padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .navigationDestination(for: CarRoute.self) { route in
                switch route {
                case .browser: BrowserPage(browser: browser)
                case .media: IPTVPage(viewModel: viewModel)
                case .touchpad: TouchpadPage()
                case .mirroring: MirrorInfoPage()
                case .maps: MapPage()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func summaryCard(symbol: String, main: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Image(systemName: symbol).font(.title2).foregroundStyle(Theme.accent)
            Text(main).font(.system(size: 22, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(sub).foregroundStyle(Theme.muted).font(.subheadline)
        }
        .frame(maxWidth: .infinity, minHeight: 125, alignment: .leading)
        .padding(17)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.border))
    }
}

private struct WatchHomeView: View {
    @ObservedObject var viewModel: ChannelViewModel
    var body: some View {
        NavigationStack {
            IPTVPage(viewModel: viewModel, standalone: true)
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct ChannelCategoryCount: Identifiable {
    let title: String
    let total: Int
    var id: String { title }
}

private struct IPTVPage: View {
    @ObservedObject var viewModel: ChannelViewModel
    var standalone = false
    @State private var search = ""
    @State private var mediaFilter = "Tudo"
    @State private var selectedSourceID: String? = nil
    @State private var onlyFavorites = false
    @State private var showingImporter = false
    @State private var showingSources = false
    @State private var selectedChannel: Channel?

    private let types = ["Tudo", "TV ao vivo", "Filmes"]

    private func movie(_ channel: Channel) -> Bool {
        let value = channel.category.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return ["movie", "filme", "cinema", "vod", "series", "séries", "pelicula"].contains(where: { value.contains($0) })
    }

    private var filtered: [Channel] {
        viewModel.channels.filter { channel in
            let belongs = selectedSourceID == nil || channel.playlistID == selectedSourceID
            let typeMatches = mediaFilter == "Tudo" || (mediaFilter == "Filmes" ? movie(channel) : !movie(channel))
            return belongs && typeMatches &&
                   (!onlyFavorites || viewModel.isFavorite(channel)) &&
                   (search.isEmpty || channel.name.localizedCaseInsensitiveContains(search) || channel.category.localizedCaseInsensitiveContains(search))
        }
    }

    private var categories: [ChannelCategoryCount] {
        let values = Dictionary(grouping: filtered, by: \.category)
        return values.map { ChannelCategoryCount(title: $0.key, total: $0.value.count) }
                     .sorted { $0.total == $1.total ? $0.title < $1.title : $0.total > $1.total }
    }

    private var recentFiltered: [Channel] {
        viewModel.recentChannels.filter { channel in filtered.contains(where: { $0.id == channel.id }) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                if !standalone { BackHeader(title: "Mídia") }
                HStack(alignment: .center, spacing: 12) {
                    Button { showingSources = true } label: {
                        Image(systemName: "tray.full")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 48, height: 48)
                            .background(Theme.raised, in: Circle())
                            .overlay(Circle().stroke(Theme.border))
                    }
                    Spacer()
                    Button { onlyFavorites.toggle() } label: {
                        Image(systemName: onlyFavorites ? "star.fill" : "star")
                            .font(.system(size: 19))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 48, height: 48)
                    }
                    Button { showingImporter = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 25, weight: .medium))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 48, height: 48)
                    }
                }
                Text("Assistir")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                HStack(spacing: 13) {
                    Image(systemName: "magnifyingglass").font(.system(size: 21)).foregroundStyle(.white.opacity(0.85))
                    TextField("Buscar canais, filmes ou séries", text: $search)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(.white)
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                    }
                }
                .padding(17)
                .background(Color(red: 0.13, green: 0.14, blue: 0.14), in: Capsule())

                HStack(spacing: 13) {
                    Image(systemName: "play.rectangle.on.rectangle").foregroundStyle(Theme.accent).font(.title3)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Minha biblioteca").font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.accent)
                        Text("\(viewModel.sources.count) fontes adicionadas").font(.system(size: 13)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Text("\(viewModel.channels.count) canais").font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                .padding(17)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 22))

                VStack(alignment: .leading, spacing: 13) {
                    HStack(spacing: 5) {
                        ForEach(types, id: \.self) { type in
                            Button { mediaFilter = type } label: {
                                Text(type)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(mediaFilter == type ? Color.black : Theme.muted)
                                    .lineLimit(1).minimumScaleFactor(0.8)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(mediaFilter == type ? Theme.accent : Color.clear, in: RoundedRectangle(cornerRadius: 15))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(5)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: 19))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 9) {
                            filterChip(title: "Favoritos", symbol: "star.fill", selected: onlyFavorites) { onlyFavorites.toggle() }
                            filterChip(title: "Todas as fontes", symbol: nil, selected: selectedSourceID == nil) { selectedSourceID = nil }
                            ForEach(viewModel.sources) { source in
                                filterChip(title: source.name, symbol: nil, selected: selectedSourceID == source.id) { selectedSourceID = source.id }
                            }
                        }
                    }
                }
                .padding(14)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 23))

                VStack(alignment: .leading, spacing: 17) {
                    Text("Reproduzidos recentemente")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                    if recentFiltered.isEmpty {
                        Text("Seus canais recentes aparecerão aqui após a primeira reprodução.")
                            .font(.subheadline).foregroundStyle(Theme.muted)
                            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 19))
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 12) {
                                ForEach(Array(recentFiltered.prefix(12))) { channel in
                                    Button { selectedChannel = channel } label: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 18).fill(Theme.panel)
                                                if let logo = channel.logoUrl {
                                                    AsyncImage(url: logo) { image in image.resizable().scaledToFit() } placeholder: {
                                                        Image(systemName: "play.tv").foregroundStyle(Theme.accent)
                                                    }
                                                    .padding(18)
                                                } else {
                                                    Image(systemName: "play.tv.fill").font(.system(size: 32)).foregroundStyle(Theme.accent)
                                                }
                                            }
                                            .frame(width: 148, height: 100)
                                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.border))
                                            Text(channel.name).font(.system(size: 14, weight: .semibold)).lineLimit(2)
                                                .foregroundStyle(.white)
                                            Text(channel.category).font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
                                        }
                                        .frame(width: 148, alignment: .leading)
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Categorias")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                    if filtered.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Nenhum canal encontrado", systemImage: "tv.slash")
                                .font(.headline)
                            Text("Adicione uma fonte M3U pelo botão + ou altere os filtros.")
                                .foregroundStyle(Theme.muted).font(.subheadline)
                            Button { showingImporter = true } label: {
                                Label("Importar lista IPTV", systemImage: "plus")
                                    .font(.headline).foregroundStyle(Color.black)
                                    .padding(13).background(Theme.accent, in: Capsule())
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .modifier(PanelModifier())
                    } else {
                        ForEach(categories) { group in
                            NavigationLink {
                                CategoryChannelsPage(viewModel: viewModel, title: group.title, channels: filtered.filter { $0.category == group.title })
                            } label: {
                                HStack(spacing: 15) {
                                    Image(systemName: "dot.radiowaves.left.and.right")
                                        .font(.system(size: 20))
                                        .foregroundStyle(Theme.accent)
                                        .frame(width: 40, height: 40)
                                        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 12))
                                    Text(group.title).font(.system(size: 17, weight: .medium)).foregroundStyle(.white)
                                    Spacer()
                                    Text("\(group.total)").foregroundStyle(Theme.muted)
                                    Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
                                }
                                .padding(14)
                                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 17))
                            }.buttonStyle(.plain)
                        }
                    }
                }
                Text("Reproduza apenas fontes para as quais você tenha autorização.")
                    .font(.footnote).foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 24)
        }
        .background(Theme.background)
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showingImporter) { PlaylistImportPage(viewModel: viewModel) }
        .sheet(isPresented: $showingSources) { SourceManagerPage(viewModel: viewModel) }
        .sheet(item: $selectedChannel) { ChannelPlayerPage(viewModel: viewModel, channel: $0) }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func filterChip(title: String, symbol: String?, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let symbol { Image(systemName: symbol) }
                Text(title).lineLimit(1)
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(selected ? Theme.accent : Theme.muted)
            .padding(.horizontal, 13).padding(.vertical, 10)
            .background(selected ? Theme.accent.opacity(0.13) : Theme.raised, in: Capsule())
            .overlay(Capsule().stroke(selected ? Theme.accent.opacity(0.65) : Theme.border))
        }
        .buttonStyle(.plain)
    }
}

private struct CategoryChannelsPage: View {
    @ObservedObject var viewModel: ChannelViewModel
    let title: String
    let channels: [Channel]
    @State private var selectedChannel: Channel?
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(channels) { channel in
                    HStack(spacing: 0) {
                        Button { selectedChannel = channel } label: { ChannelRowCard(channel: channel) }
                            .buttonStyle(.plain)
                        Button { viewModel.toggleFavorite(channel) } label: {
                            Image(systemName: viewModel.isFavorite(channel) ? "star.fill" : "star")
                                .foregroundStyle(Theme.accent).padding(17)
                        }
                    }
                    .background(Theme.panel, in: RoundedRectangle(cornerRadius: 16))
                }
            }.padding(16)
        }
        .background(Theme.background)
        .navigationTitle(title)
        .sheet(item: $selectedChannel) { ChannelPlayerPage(viewModel: viewModel, channel: $0) }
    }
}

private struct SourceManagerPage: View {
    @ObservedObject var viewModel: ChannelViewModel
    @State private var adding = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.sources) { source in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(source.name).font(.headline)
                            Text("\(source.channelCount) canais").font(.caption).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Button(role: .destructive) { viewModel.removeSource(source) } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
                if viewModel.sources.isEmpty {
                    Text("Nenhuma lista importada.").foregroundStyle(Theme.muted)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Fontes IPTV")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Fechar") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button { adding = true } label: { Image(systemName: "plus") } }
            }
            .sheet(isPresented: $adding) { PlaylistImportPage(viewModel: viewModel) }
        }
        .preferredColorScheme(.dark)
    }
}

private struct ChannelRowCard: View {
    let channel: Channel
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 13).fill(Theme.accent.opacity(0.12)).frame(width: 57, height: 53)
                if let url = channel.logoUrl {
                    AsyncImage(url: url) { image in image.resizable().scaledToFit() } placeholder: {
                        Image(systemName: "play.tv").foregroundStyle(Theme.accent)
                    }
                    .frame(width: 48, height: 43)
                } else { Image(systemName: "play.tv.fill").foregroundStyle(Theme.accent).font(.title2) }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(channel.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).lineLimit(2)
                Text(channel.category).font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "play.circle").foregroundStyle(Theme.accent).font(.title2)
        }
        .padding(12)
        .contentShape(Rectangle())
    }
}

private struct PlaylistImportPage: View {
    @ObservedObject var viewModel: ChannelViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var enteredURL = ""
    @State private var working = false
    @State private var showFileImporter = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PageHeading(title: "Importar lista", subtitle: "M3U / M3U8")
                    Text("Cole uma URL de playlist ou importe um arquivo local.")
                        .foregroundStyle(Theme.muted)
                    TextField("https://servidor.exemplo/lista.m3u", text: $enteredURL, axis: .vertical)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .keyboardType(.URL)
                        .padding(15).background(Theme.raised, in: RoundedRectangle(cornerRadius: 15))
                    Button {
                        working = true
                        Task { await viewModel.importURL(enteredURL); working = false }
                    } label: {
                        HStack { if working { ProgressView() }; Text("Importar por URL"); Image(systemName: "arrow.down.circle") }
                            .font(.headline).frame(maxWidth: .infinity).padding(16)
                            .foregroundStyle(Color.black).background(Theme.accent, in: RoundedRectangle(cornerRadius: 15))
                    }
                    .disabled(working || enteredURL.isEmpty)
                    Button { showFileImporter = true } label: {
                        Label("Escolher arquivo M3U", systemImage: "doc.badge.plus")
                            .frame(maxWidth: .infinity).padding(16)
                            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 15))
                    }
                    if let message = viewModel.importMessage {
                        Label(message, systemImage: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                        Button("Voltar à biblioteca") { viewModel.importMessage = nil; dismiss() }
                    }
                    Text("O StreamPlay salva listas importadas no iPhone. URLs com usuário e senha não são enviadas ao nosso servidor; não há servidor intermediário.")
                        .font(.footnote).foregroundStyle(Theme.muted)
                }
                .padding(22)
            }
            .background(Theme.background)
            .navigationTitle("Adicionar IPTV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fechar") { dismiss() } } }
            .fileImporter(isPresented: $showFileImporter,
                          allowedContentTypes: [UTType(filenameExtension: "m3u") ?? .plainText,
                                                UTType(filenameExtension: "m3u8") ?? .plainText, .plainText],
                          allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls): if let url = urls.first { viewModel.importFile(url) }
                case .failure(let error): viewModel.errorMessage = error.localizedDescription
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct ChannelPlayerPage: View {
    @ObservedObject var viewModel: ChannelViewModel
    @ObservedObject private var car = CarDisplayCoordinator.shared
    let channel: Channel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VideoPlayer(player: viewModel.player)
                        .aspectRatio(16/9, contentMode: .fit)
                        .background(.black, in: RoundedRectangle(cornerRadius: 12))
                    Text(channel.name).font(.system(size: 27, weight: .bold, design: .rounded))
                    Text(channel.category).foregroundStyle(Theme.muted)
                    HStack(spacing: 12) {
                        Button { viewModel.togglePlayback() } label: {
                            Label(viewModel.isPlaying ? "Pausar" : "Reproduzir", systemImage: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                .frame(maxWidth: .infinity).padding(15)
                                .foregroundStyle(.black).background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
                        }
                        Button { viewModel.stop() } label: {
                            Label("Parar", systemImage: "stop.fill").padding(15)
                                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    Button { car.showMedia() } label: {
                        Label("Mostrar no carro \(car.connected ? "" : "(aguardando conexão)")", systemImage: "car.side.fill")
                            .frame(maxWidth: .infinity).padding(16)
                            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 15))
                    }
                    HStack {
                        Text("Saída de áudio/vídeo").font(.subheadline).foregroundStyle(Theme.muted)
                        Spacer()
                        AirPlayRoutePicker().frame(width: 48, height: 44)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Label(viewModel.playbackStatus, systemImage: viewModel.playbackFailure == nil ? "waveform.path" : "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(viewModel.playbackFailure == nil ? Theme.accent : .orange)
                        if viewModel.isLoading { ProgressView("Carregando stream…") }
                        if let failure = viewModel.playbackFailure {
                            Text(failure).font(.footnote).foregroundStyle(.orange)
                            Button { viewModel.retry() } label: {
                                Label("Tentar canal novamente", systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity).padding(13)
                                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: 14))
                            }
                        }
                        DisclosureGroup("Diagnóstico do player") {
                            Text(viewModel.playbackDiagnostic)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Theme.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                            Button("Copiar diagnóstico") {
                                UIPasteboard.general.string = viewModel.diagnosticReport
                            }
                            .buttonStyle(.bordered)
                        }
                        .font(.subheadline)
                    }
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.panel, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(18)
            }
            .background(Theme.background)
            .navigationTitle("Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fechar") { dismiss() } } }
        }
        .onAppear { viewModel.select(channel) }
    }
}

private struct BackHeader: View {
    let title: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        HStack(spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 48, height: 48)
                    .background(Theme.raised, in: Circle())
                    .overlay(Circle().stroke(Theme.border))
            }
            Text(title).font(.system(size: 19, weight: .semibold)).foregroundStyle(.white)
            Spacer()
        }
    }
}

private struct BrowserPage: View {
    @ObservedObject var browser: BrowserStore
    @ObservedObject private var car = CarDisplayCoordinator.shared
    @State private var showTabSheet = false
    @State private var showTouchpad = false

    var body: some View {
        VStack(spacing: 14) {
            BackHeader(title: "Navegador")
            BrowserTabBody(tab: browser.activeTab, browser: browser,
                           showTabs: { showTabSheet = true }, showTouchpad: { showTouchpad = true })
                .id(browser.activeTabID)
        }
        .padding(.horizontal, 16).padding(.top, 10)
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showTabSheet) { BrowserTabsPage(browser: browser) }
        .sheet(isPresented: $showTouchpad) { TouchpadPage() }
    }
}

private struct BrowserTabBody: View {
    @ObservedObject var tab: BrowserTab
    @ObservedObject var browser: BrowserStore
    let showTabs: () -> Void
    let showTouchpad: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "globe").foregroundStyle(Theme.accent)
                TextField("Endereço ou busca", text: $tab.address)
                    .keyboardType(.webSearch).textInputAutocapitalization(.never)
                    .autocorrectionDisabled().submitLabel(.go)
                    .onSubmit { tab.navigate(tab.address) }
                Button { tab.navigate(tab.address) } label: { Image(systemName: "arrow.right.circle.fill").font(.title2) }
            }
            .padding(16).background(Theme.raised, in: RoundedRectangle(cornerRadius: 17))
            HStack(spacing: 9) {
                browserTool("square.grid.2x2") { tab.goHome() }
                browserTool("chevron.left", enabled: tab.canGoBack) { tab.goBack() }
                browserTool("chevron.right", enabled: tab.canGoForward) { tab.goForward() }
                browserTool("arrow.clockwise") { tab.reload() }
                browserTool(browser.isBookmarked ? "bookmark.fill" : "bookmark") { browser.toggleBookmark() }
                browserTool("square.on.square") { showTabs() }
                Spacer(minLength: 0)
            }
            HStack(spacing: 9) {
                browserTool("gobackward.10") { tab.mediaCommand("back10") }
                browserTool("playpause.fill") { tab.mediaCommand("playPause") }
                browserTool("goforward.10") { tab.mediaCommand("forward10") }
                browserTool("hand.draw.fill") { showTouchpad() }
                Spacer()
                Text(CarDisplayCoordinator.shared.connected ? "CARRO ONLINE" : "SEM CARPLAY")
                    .font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.muted)
            }
            if tab.isLoading { ProgressView().tint(Theme.accent).frame(maxWidth: .infinity) }
            Group {
                if tab.currentURL == nil {
                    BrowserStartPage(browser: browser) { url in tab.load(url) }
                } else {
                    PhoneWebView(webView: tab.webView)
                        .background(.black)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if let error = tab.loadError {
                Text(error).font(.footnote).foregroundStyle(.orange).lineLimit(2)
            }
        }
        .onChange(of: tab.currentURL) { _, url in
            if url != nil { browser.rememberCurrentPage() }
        }
    }
    private func browserTool(_ symbol: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 17, weight: .medium))
                .foregroundStyle(enabled ? Theme.accent : Theme.muted.opacity(0.55))
                .frame(width: 43, height: 43)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 13))
        }
        .disabled(!enabled)
    }
}

private struct PhoneWebView: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

private struct BrowserStartPage: View {
    @ObservedObject var browser: BrowserStore
    let open: (URL) -> Void
    private struct Shortcut: Identifiable {
        let id: String
        let icon: String
        let link: String
        let color: Color
    }
    private let destinations: [Shortcut] = [
        Shortcut(id: "Google", icon: "G", link: "https://www.google.com", color: .blue),
        Shortcut(id: "YouTube", icon: "play.fill", link: "https://m.youtube.com", color: .red),
        Shortcut(id: "Twitch", icon: "bubble.fill", link: "https://m.twitch.tv", color: .purple),
        Shortcut(id: "Vimeo", icon: "V", link: "https://vimeo.com", color: .cyan),
        Shortcut(id: "Dailymotion", icon: "D", link: "https://www.dailymotion.com", color: .blue),
        Shortcut(id: "Plex", icon: "chevron.right", link: "https://app.plex.tv", color: .orange),
        Shortcut(id: "Wikipedia", icon: "W", link: "https://www.wikipedia.org", color: .gray),
        Shortcut(id: "DuckDuckGo", icon: "D", link: "https://duckduckgo.com", color: .orange)
    ]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                Text("Navegador").font(.system(size: 25, weight: .semibold)).foregroundStyle(.white)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 25) {
                    ForEach(destinations) { item in
                        Button {
                            if let url = URL(string: item.link) { open(url) }
                        } label: {
                            VStack(spacing: 9) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14).fill(item.color.gradient)
                                        .frame(width: 60, height: 60)
                                    if item.icon.count == 1 {
                                        Text(item.icon).font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
                                    } else {
                                        Image(systemName: item.icon).font(.title).foregroundStyle(.white)
                                    }
                                }
                                Text(item.id).font(.caption).foregroundStyle(.white).lineLimit(1)
                            }
                        }
                    }
                }
                bookmarkSection(title: "Favoritos", symbol: "bookmark", bookmarks: browser.bookmarks)
                bookmarkSection(title: "Histórico", symbol: "clock.arrow.circlepath", bookmarks: Array(browser.history.prefix(8)))
            }
            .padding(18)
        }
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.border))
    }
    private func bookmarkSection(title: String, symbol: String, bookmarks: [BrowserBookmark]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol).foregroundStyle(Theme.muted).font(.headline)
            if bookmarks.isEmpty { Text("Nenhum item ainda.").font(.subheadline).foregroundStyle(Theme.muted) }
            ForEach(bookmarks) { bookmark in
                Button { open(bookmark.url) } label: {
                    HStack { Image(systemName: "globe").foregroundStyle(Theme.accent)
                        Text(bookmark.title).foregroundStyle(.white).lineLimit(1)
                        Spacer(); Image(systemName: "arrow.up.right").foregroundStyle(Theme.muted) }
                    .padding(11).background(Theme.raised, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

private struct BrowserTabsPage: View {
    @ObservedObject var browser: BrowserStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                ForEach(browser.tabs) { tab in
                    HStack {
                        Button { browser.selectTab(tab.id); dismiss() } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(tab.title).font(.headline).foregroundStyle(.white)
                                Text(tab.address.isEmpty ? "Nova aba" : tab.address)
                                    .font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
                            }
                        }
                        Spacer()
                        Button { browser.closeTab(tab.id) } label: { Image(systemName: "xmark.circle.fill") }
                    }
                }
            }
            .scrollContentBackground(.hidden).background(Theme.background)
            .navigationTitle("Abas (\(browser.tabs.count))")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Fechar") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button { browser.newTab(); dismiss() } label: { Image(systemName: "plus") } }
            }
        }.preferredColorScheme(.dark)
    }
}

private struct TouchpadPage: View {
    @ObservedObject private var car = CarDisplayCoordinator.shared
    @Environment(\.dismiss) private var dismiss
    @State private var lastTranslation: CGSize = .zero
    @State private var remoteText = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack {
                Button { dismiss() } label: { Image(systemName: "chevron.left").font(.title2) }
                Text("Touchpad").font(.system(size: 25, weight: .bold))
                Spacer()
                Circle().fill(car.connected ? Theme.accent : .gray).frame(width: 10, height: 10)
                Text(car.connected ? "Conectado" : "Aguardando CarPlay")
                    .foregroundStyle(Theme.muted).font(.caption)
            }
            SectionEyebrow(title: "Controle do navegador")
            GeometryReader { geometry in
                ZStack {
                    RoundedRectangle(cornerRadius: 28).fill(Theme.raised)
                        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Theme.border, lineWidth: 1.5))
                    VStack(spacing: 10) {
                        Image(systemName: "cursorarrow.rays").font(.system(size: 44)).foregroundStyle(Theme.accent)
                        Text("Arraste para mover o cursor")
                        Text("Toque para clicar · Use as setas para rolar")
                            .font(.footnote).foregroundStyle(Theme.muted)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 28))
                .gesture(DragGesture(minimumDistance: 3)
                    .onChanged { value in
                        let dx = value.translation.width - lastTranslation.width
                        let dy = value.translation.height - lastTranslation.height
                        car.movePointer(dx: dx, dy: dy)
                        lastTranslation = value.translation
                    }
                    .onEnded { _ in lastTranslation = .zero })
                .simultaneousGesture(TapGesture().onEnded { car.click() })
                .accessibilityLabel("Área do touchpad remoto")
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            HStack(spacing: 12) {
                Button { car.scroll(-320) } label: { Label("Subir", systemImage: "arrow.up") }
                Button { car.click() } label: { Label("Clicar", systemImage: "cursorarrow.click") }
                Button { car.scroll(320) } label: { Label("Descer", systemImage: "arrow.down") }
            }
            .buttonStyle(.bordered).frame(maxWidth: .infinity)
            HStack(spacing: 10) {
                TextField("Texto para campo selecionado", text: $remoteText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: 12))
                Button("Enviar") { car.typeText(remoteText) }
                    .disabled(remoteText.isEmpty)
                    .font(.headline)
            }
            Text(car.connected ? "Os comandos são enviados à cena do carro." : "O touchpad só controla a cena visual quando o CarPlay cria uma janela autorizada para este aplicativo.")
                .font(.footnote).foregroundStyle(Theme.muted)
        }
        .padding(20)
        .background(Theme.background)
    }
}

private struct MirrorInfoPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BackHeader(title: "Espelhamento")
                PageHeading(title: "Espelhar iPhone", subtitle: "Transmissão de tela")
                Image(systemName: "rectangle.on.rectangle")
                    .font(.system(size: 60)).foregroundStyle(Theme.accent).frame(maxWidth: .infinity).padding(30)
                Text("O espelhamento depende de uma saída AirPlay compatível com sua central. Ele não é habilitado pelo CarPlay comum nem pelo Sideloadly.")
                Text("Para testar uma saída disponível: abra a Central de Controle do iPhone → Espelhamento de Tela → selecione um dispositivo AirPlay compatível.")
                    .foregroundStyle(Theme.muted)
                Text("O StreamPlay não apresenta um botão falso de transmissão: quando o sistema não oferecer uma rota visual, não há imagem para enviar.")
                    .font(.footnote).foregroundStyle(Theme.muted)
            }.padding(20)
        }.background(Theme.background).toolbar(.hidden, for: .navigationBar)
    }
}

private struct MapPage: View {
    var body: some View {
        VStack(spacing: 8) {
            PageHeading(title: "Mapas", subtitle: "Explorar")
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.top, 20)
            Map().mapControls {
                MapCompass()
                MapScaleView()
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 12).padding(.bottom, 12)
        }
        .background(Theme.background).toolbar(.hidden, for: .navigationBar)
    }
}

private struct SettingsPage: View {
    @ObservedObject var viewModel: ChannelViewModel
    @ObservedObject private var car = CarDisplayCoordinator.shared
    @State private var showHelp = false
    @State private var showSources = false
    @State private var showCarDetails = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 23) {
                    HStack(spacing: 11) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 58, height: 58)
                            .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("StreamPlay").font(.system(size: 21, weight: .semibold)).foregroundStyle(.white)
                            Text("IPTV, navegador e controle touchpad no iPhone.")
                                .font(.subheadline).foregroundStyle(Theme.muted)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(17)
                    .background(Theme.panel, in: RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.accent.opacity(0.5)))

                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            settingsIcon("bolt.fill", color: Theme.accent)
                            Text("Qualidade da reprodução").font(.system(size: 17, weight: .medium))
                            Spacer()
                            Picker("Qualidade", selection: $viewModel.quality) {
                                ForEach(PlaybackQuality.allCases) { quality in
                                    Text(quality.rawValue).tag(quality)
                                }
                            }
                            .labelsHidden().tint(Theme.muted)
                        }
                        .frame(minHeight: 74)
                        settingsDivider
                        Button { showCarDetails = true } label: {
                            settingsRow(icon: "car.side.fill", title: "Tela do carro", detail: car.connected ? "Conectado" : "Aguardando")
                        }.buttonStyle(.plain)
                        settingsDivider
                        settingsRow(icon: "dot.radiowaves.left.and.right", title: "Receptor DLNA / UPnP", detail: "Não disponível")
                    }
                    .modifier(PanelModifier())
                    Text("A qualidade acima controla o bitrate e a resolução preferidos do HLS no iPhone. Não altera o sinal enviado ao CarPlay.")
                        .font(.footnote).foregroundStyle(Theme.muted)

                    VStack(spacing: 0) {
                        Button { showSources = true } label: {
                            settingsRow(icon: "tray.full.fill", title: "Fontes IPTV", detail: "\(viewModel.sources.count) listas")
                        }.buttonStyle(.plain)
                        settingsDivider
                        Button { showHelp = true } label: {
                            settingsRow(icon: "questionmark.circle", title: "Ajuda e perguntas frequentes", detail: "")
                        }.buttonStyle(.plain)
                    }
                    .modifier(PanelModifier())

                    Text("App")
                        .font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.muted)
                        .padding(.horizontal, 14)
                    VStack(spacing: 0) {
                        settingsRow(icon: "play.rectangle.fill", title: "Vídeo · codec da fonte", detail: viewModel.videoCodec)
                        settingsDivider
                        settingsRow(icon: "cpu", title: "Codec de saída", detail: "Sem transmissão ativa")
                        settingsDivider
                        settingsRow(icon: "display", title: "Tela de destino", detail: car.connected ? "CarPlay detectado" : "iPhone")
                        settingsDivider
                        settingsRow(icon: "checkmark.shield", title: "Autorização de vídeo CarPlay", detail: "Requer Apple")
                    }
                    .modifier(PanelModifier())

                    Text("Codec H.264 na tela do LeyTV pode indicar seu encoder de saída. Aqui mostramos o codec detectado no stream de entrada; isso não significa que o StreamPlay esteja transmitindo vídeo ao carro.")
                        .font(.footnote).foregroundStyle(Theme.muted)
                    Text("StreamPlay v4.2 · Referência visual: layout observado no LeyTV; identidade e implementação independentes.")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, 19)
                .padding(.top, 26)
                .padding(.bottom, 25)
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showCarDetails) { CarDiagnosticsPage() }
            .sheet(isPresented: $showSources) { SourceManagerPage(viewModel: viewModel) }
            .sheet(isPresented: $showHelp) { HelpPage() }
        }
    }

    private var settingsDivider: some View {
        Divider().overlay(Theme.border).padding(.leading, 55)
    }

    private func settingsIcon(_ symbol: String, color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(color)
            .frame(width: 42, height: 42)
            .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 13))
    }

    private func settingsRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 13) {
            settingsIcon(icon, color: Theme.accent)
            Text(title).font(.system(size: 16, weight: .medium)).foregroundStyle(.white)
            Spacer(minLength: 8)
            if !detail.isEmpty {
                Text(detail).font(.system(size: 13)).foregroundStyle(Theme.muted)
                    .lineLimit(2).multilineTextAlignment(.trailing)
            }
            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Theme.muted)
        }.frame(minHeight: 72)
    }
}

private struct CarDiagnosticsPage: View {
    @ObservedObject private var car = CarDisplayCoordinator.shared
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Text("Conexão CarPlay").font(.system(size: 30, weight: .bold))
                Label(car.connected ? "Cena visual conectada" : "Nenhuma cena visual conectada",
                      systemImage: car.connected ? "checkmark.circle.fill" : "exclamationmark.triangle")
                    .foregroundStyle(car.connected ? Theme.accent : .orange)
                Text("O aplicativo pode aparecer como áudio no CarPlay sem obter permissão para exibir um navegador ou vídeo. iOS e assinatura controlam esse acesso.")
                Text("Em veículos compatíveis, a reprodução visual deve respeitar o estado estacionado. A instalação via sideload não libera entitlements CarPlay.")
                    .foregroundStyle(Theme.muted)
            }.padding(20)
        }
        .background(Theme.background)
        .navigationTitle("Tela do carro")
    }
}

private struct HelpPage: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    help("Como adicionar IPTV?", "Abra Assistir e toque no sinal de + para importar uma lista M3U por arquivo ou endereço HTTPS.")
                    help("Como usar o navegador?", "Na aba Carro, toque em Navegador. Os sites são carregados com WKWebView no iPhone.")
                    help("Como usar o touchpad?", "Na aba Carro, abra o controle touchpad. Ele só controla uma janela CarPlay personalizada quando autorizada pelo sistema.")
                    help("H.264 é obrigatório?", "Não. O formato depende do conteúdo e das capacidades de reprodução. O valor em Ajustes é uma detecção, não uma conversão automática.")
                }.padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Ajuda")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fechar") { dismiss() } } }
        }.preferredColorScheme(.dark)
    }
    private func help(_ question: String, _ answer: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question).font(.headline).foregroundStyle(.white)
            Text(answer).font(.subheadline).foregroundStyle(Theme.muted)
        }.modifier(PanelModifier())
    }
}

private struct PanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.frame(maxWidth: .infinity, alignment: .leading)
            .padding(17).background(Theme.panel, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border))
    }
}
