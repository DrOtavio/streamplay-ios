import SwiftUI
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
    @State private var selectedTab: MainTab = .car

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

private struct IPTVPage: View {
    @ObservedObject var viewModel: ChannelViewModel
    var standalone = false
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var category = "Todos"
    @State private var onlyFavorites = false
    @State private var showingImporter = false
    @State private var selectedChannel: Channel?

    private var categories: [String] {
        ["Todos"] + Array(Set(viewModel.channels.map(\.category))).sorted()
    }
    private var filtered: [Channel] {
        viewModel.channels.filter {
            (category == "Todos" || $0.category == category) &&
            (!onlyFavorites || viewModel.isFavorite($0)) &&
            (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 21) {
                if !standalone { BackHeader(title: "Mídia") }
                PageHeading(title: "Assistir", subtitle: "Biblioteca IPTV")
                HStack(spacing: 13) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.accent)
                    TextField("Buscar canal", text: $search).autocorrectionDisabled()
                        .foregroundStyle(.white)
                    if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill") } }
                }
                .padding(15).background(Theme.raised, in: RoundedRectangle(cornerRadius: 17))
                HStack(spacing: 10) {
                    Button { showingImporter = true } label: {
                        Label("Adicionar M3U", systemImage: "plus.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 16).padding(.vertical, 13)
                            .background(Theme.accent, in: Capsule())
                    }
                    Button { onlyFavorites.toggle() } label: {
                        Image(systemName: onlyFavorites ? "star.fill" : "star")
                            .frame(width: 45, height: 45)
                            .background(Theme.raised, in: Circle())
                    }
                    Spacer()
                    Text("\(viewModel.channels.count) canais")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(categories, id: \.self) { name in
                            Button { category = name } label: {
                                Text(name).font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(category == name ? Color.black : .white)
                                    .padding(.horizontal, 15).padding(.vertical, 10)
                                    .background(category == name ? Theme.accent : Theme.raised, in: Capsule())
                            }
                        }
                    }
                }
                if filtered.isEmpty {
                    VStack(spacing: 13) {
                        Image(systemName: "tv.slash").font(.system(size: 40)).foregroundStyle(Theme.muted)
                        Text("Nenhum canal encontrado").font(.headline)
                        Text("Importe sua lista M3U ou altere os filtros.").font(.subheadline).foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity).padding(35)
                    .background(Theme.panel, in: RoundedRectangle(cornerRadius: 22))
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(filtered) { channel in
                            HStack(spacing: 0) {
                                Button { selectedChannel = channel } label: { ChannelRowCard(channel: channel) }
                                    .buttonStyle(.plain)
                                Button { viewModel.toggleFavorite(channel) } label: {
                                    Image(systemName: viewModel.isFavorite(channel) ? "star.fill" : "star")
                                        .font(.system(size: 19))
                                        .foregroundStyle(Theme.accent)
                                        .padding(17)
                                }
                            }
                            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 19))
                            .overlay(RoundedRectangle(cornerRadius: 19).stroke(Theme.border))
                        }
                    }
                }
                Text("Use somente listas e transmissões para as quais você tenha autorização.")
                    .font(.footnote).foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 20).padding(.top, 23).padding(.bottom, 25)
        }
        .background(Theme.background)
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showingImporter) { PlaylistImportPage(viewModel: viewModel) }
        .sheet(item: $selectedChannel) { ChannelPlayerPage(viewModel: viewModel, channel: $0) }
        .toolbar(.hidden, for: .navigationBar)
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
                    if viewModel.isLoading { ProgressView("Carregando stream…") }
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
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PageHeading(title: "Ajustes", subtitle: "StreamPlay")
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Fontes IPTV (\(viewModel.sources.count))", systemImage: "list.bullet.rectangle").font(.headline)
                        if viewModel.sources.isEmpty {
                            Text("Nenhuma lista importada. Abra Assistir para adicionar uma URL ou arquivo M3U.")
                                .font(.subheadline).foregroundStyle(Theme.muted)
                        }
                        ForEach(viewModel.sources) { source in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(source.name).font(.subheadline.bold())
                                    Text("\(source.channelCount) canais").font(.caption).foregroundStyle(Theme.muted)
                                }
                                Spacer()
                                Button(role: .destructive) { viewModel.removeSource(source) } label: { Image(systemName: "trash") }
                            }
                            Divider().overlay(Theme.border)
                        }
                    }.modifier(PanelModifier())
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Reprodução", systemImage: "speaker.wave.2.fill").font(.headline)
                        Slider(value: Binding(get: { Double(viewModel.volume) },
                                              set: { viewModel.setVolume(Float($0)) }), in: 0...1)
                        Button("Parar reprodução", role: .destructive) { viewModel.stop() }
                    }.modifier(PanelModifier())
                    VStack(alignment: .leading, spacing: 9) {
                        Label("Diagnóstico CarPlay", systemImage: "car.side.fill").font(.headline)
                        Text("Janela autorizada: \(car.connected ? "conectada" : "não conectada")")
                        Text("Modo templates: \(CarPlayMode.configured.rawValue)")
                        Text("No iOS 26, a janela experimental exige assinatura com entitlements concedidos pela Apple. Sideloadly com Personal Team não fornece essa permissão.")
                            .font(.footnote).foregroundStyle(Theme.muted)
                    }.modifier(PanelModifier())
                    Text("StreamPlay 4.0 · Navegador + IPTV · Interface original inspirada na experiência de uso do LeyTV.")
                        .font(.footnote).foregroundStyle(Theme.muted)
                }.padding(20)
            }.background(Theme.background).toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct PanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.frame(maxWidth: .infinity, alignment: .leading)
            .padding(17).background(Theme.panel, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border))
    }
}
