import Foundation
import Combine
import WebKit
import UIKit

/// Each tab owns a separate WKWebView. A web view cannot be attached to two windows.
@MainActor
final class BrowserTab: NSObject, ObservableObject, Identifiable, WKNavigationDelegate {
    let id = UUID()
    let webView: WKWebView
    @Published var address = ""
    @Published var title = "Nova aba"
    @Published var currentURL: URL?
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var loadError: String?

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.035, green: 0.055, blue: 0.050, alpha: 1)
    }

    func navigate(_ input: String) {
        let candidate = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return }
        let url: URL?
        if let direct = URL(string: candidate), ["http", "https"].contains(direct.scheme?.lowercased() ?? "") {
            url = direct
        } else if candidate.contains(".") && !candidate.contains(" ") {
            url = URL(string: "https://" + candidate)
        } else {
            var components = URLComponents(string: "https://www.google.com/search")
            components?.queryItems = [URLQueryItem(name: "q", value: candidate)]
            url = components?.url
        }
        guard let url else { loadError = "Endereço inválido."; return }
        load(url)
    }

    func load(_ url: URL) {
        address = url.absoluteString
        currentURL = url
        loadError = nil
        webView.load(URLRequest(url: url))
        CarDisplayCoordinator.shared.showBrowser(url: url)
    }
    func goHome() {
        webView.stopLoading()
        webView.loadHTMLString("<html><body></body></html>", baseURL: nil)
        currentURL = nil
        address = ""
        title = "Nova aba"
    }
    func goBack() { if webView.canGoBack { webView.goBack() } }
    func goForward() { if webView.canGoForward { webView.goForward() } }
    func reload() { webView.reload() }

    func mediaCommand(_ command: String) {
        let javascript: String
        switch command {
        case "playPause":
            javascript = "var v=document.querySelector('video');if(v){v.paused?v.play():v.pause();}"
        case "back10":
            javascript = "var v=document.querySelector('video');if(v){v.currentTime=Math.max(0,v.currentTime-10);}"
        case "forward10":
            javascript = "var v=document.querySelector('video');if(v){v.currentTime+=10;}"
        default: return
        }
        webView.evaluateJavaScript(javascript, completionHandler: nil)
    }

    private func update() {
        let url = webView.url
        if url?.scheme == "about" {
            address = ""
            currentURL = nil
            title = "Nova aba"
        } else {
            address = url?.absoluteString ?? address
            currentURL = url
            title = webView.title ?? "Navegador"
        }
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        isLoading = webView.isLoading
        if let url = currentURL { CarDisplayCoordinator.shared.followPhoneNavigation(url: url) }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        loadError = nil
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { update() }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        loadError = error.localizedDescription
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        loadError = error.localizedDescription
    }
}

@MainActor
final class BrowserStore: ObservableObject {
    @Published private(set) var tabs: [BrowserTab]
    @Published var activeTabID: UUID
    @Published private(set) var bookmarks: [BrowserBookmark] = []
    @Published private(set) var history: [BrowserBookmark] = []

    private let bookmarkKey = "streamplay.v4.browser.bookmarks"
    private let historyKey = "streamplay.v4.browser.history"

    init() {
        // Do not access self.tabs until all stored properties have been initialized.
        // The initial tab and active ID must refer to the same BrowserTab instance.
        let firstTab = BrowserTab()
        self.tabs = [firstTab]
        self.activeTabID = firstTab.id
        if let data = UserDefaults.standard.data(forKey: bookmarkKey),
           let decoded = try? JSONDecoder().decode([BrowserBookmark].self, from: data) { bookmarks = decoded }
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([BrowserBookmark].self, from: data) { history = decoded }
    }

    var activeTab: BrowserTab { tabs.first(where: { $0.id == activeTabID }) ?? tabs[0] }
    var isBookmarked: Bool { activeTab.currentURL.map { url in bookmarks.contains(where: { $0.url == url }) } ?? false }

    func newTab() { let tab = BrowserTab(); tabs.append(tab); activeTabID = tab.id }
    func selectTab(_ id: UUID) { if tabs.contains(where: { $0.id == id }) { activeTabID = id } }
    func closeTab(_ id: UUID) {
        tabs.removeAll { $0.id == id }
        if tabs.isEmpty { tabs = [BrowserTab()] }
        if !tabs.contains(where: { $0.id == activeTabID }) { activeTabID = tabs[0].id }
    }
    func open(_ url: URL) { activeTab.load(url) }

    func toggleBookmark() {
        guard let url = activeTab.currentURL else { return }
        if bookmarks.contains(where: { $0.url == url }) {
            bookmarks.removeAll { $0.url == url }
        } else {
            bookmarks.insert(BrowserBookmark(id: UUID(), title: activeTab.title, url: url), at: 0)
        }
        save(bookmarks, key: bookmarkKey)
    }

    func rememberCurrentPage() {
        guard let url = activeTab.currentURL else { return }
        history.removeAll { $0.url == url }
        history.insert(BrowserBookmark(id: UUID(), title: activeTab.title, url: url), at: 0)
        if history.count > 40 { history = Array(history.prefix(40)) }
        save(history, key: historyKey)
    }

    private func save(_ records: [BrowserBookmark], key: String) {
        if let data = try? JSONEncoder().encode(records) { UserDefaults.standard.set(data, forKey: key) }
    }
}
