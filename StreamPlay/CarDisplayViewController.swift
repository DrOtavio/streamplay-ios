import UIKit
import WebKit
import AVKit

/// Own-window rendering path, not a view pushed onto CPInterfaceController.
/// Browser content is a second WKWebView; the phone's WKWebView stays on the phone.
@MainActor
final class CarDisplayViewController: UIViewController, WKNavigationDelegate {
    private let webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let web = WKWebView(frame: .zero, configuration: configuration)
        web.translatesAutoresizingMaskIntoConstraints = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        return web
    }()
    private let playerController = PlayerViewController()
    private let statusLabel = UILabel()
    private let cursor = UIImageView(image: UIImage(systemName: "cursorarrow.rays"))
    private var pointerLocation = CGPoint(x: 120, y: 150)
    private var loadedURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.025, green: 0.04, blue: 0.035, alpha: 1)
        webView.navigationDelegate = self
        view.addSubview(webView)
        addChild(playerController)
        playerController.player = AppServices.shared.viewModel.player
        playerController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playerController.view)
        playerController.didMove(toParent: self)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            playerController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerController.view.topAnchor.constraint(equalTo: view.topAnchor),
            playerController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        statusLabel.text = "STREAMPLAY  •  SOMENTE ESTACIONADO"
        statusLabel.textColor = UIColor(red: 0.83, green: 1, blue: 0.43, alpha: 1)
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.72)
        statusLabel.font = UIFont.boldSystemFont(ofSize: 13)
        statusLabel.layer.cornerRadius = 8
        statusLabel.layer.masksToBounds = true
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            statusLabel.widthAnchor.constraint(equalToConstant: 260),
            statusLabel.heightAnchor.constraint(equalToConstant: 34)
        ])
        cursor.tintColor = UIColor(red: 0.83, green: 1, blue: 0.43, alpha: 1)
        cursor.contentMode = .scaleAspectFit
        cursor.frame = CGRect(x: 110, y: 140, width: 30, height: 30)
        view.addSubview(cursor)
        showStandby()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        pointerLocation.x = min(max(15, pointerLocation.x), max(15, webView.bounds.width - 20))
        pointerLocation.y = min(max(15, pointerLocation.y), max(15, webView.bounds.height - 20))
        cursor.center = pointerLocation
    }

    func showStandby() {
        loadIfNeeded()
        webView.isHidden = true
        playerController.view.isHidden = true
        cursor.isHidden = true
        statusLabel.text = "STREAMPLAY  •  AGUARDANDO CONTEÚDO"
    }

    func showBrowser(_ url: URL) {
        loadIfNeeded()
        webView.isHidden = false
        playerController.view.isHidden = true
        cursor.isHidden = false
        statusLabel.text = "NAVEGADOR  •  SOMENTE ESTACIONADO"
        if loadedURL != url {
            loadedURL = url
            webView.load(URLRequest(url: url))
        }
    }

    func showMedia() {
        loadIfNeeded()
        webView.isHidden = true
        playerController.view.isHidden = false
        cursor.isHidden = true
        statusLabel.text = "IPTV  •  SOMENTE ESTACIONADO"
    }

    private func loadIfNeeded() { loadViewIfNeeded() }

    func movePointer(dx: CGFloat, dy: CGFloat) {
        guard !webView.isHidden else { return }
        pointerLocation.x = min(max(8, pointerLocation.x + dx * 1.6), max(8, webView.bounds.width - 8))
        pointerLocation.y = min(max(8, pointerLocation.y + dy * 1.6), max(8, webView.bounds.height - 8))
        cursor.center = pointerLocation
    }

    func click() {
        guard !webView.isHidden else { return }
        // Synthetic DOM click works on many links/buttons. Some sites require
        // trusted gestures; that limitation cannot be bypassed with public APIs.
        let x = Int(pointerLocation.x)
        let y = Int(pointerLocation.y)
        let js = "(function(){var e=document.elementFromPoint(\(x),\(y)); if(e){(e.closest('a,button,input,[role=button]')||e).click(); return true;}return false;})()"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    func scroll(_ amount: CGFloat) {
        guard !webView.isHidden else { return }
        let pixels = Int(amount)
        webView.evaluateJavaScript("window.scrollBy({top:\(pixels),behavior:'smooth'});", completionHandler: nil)
    }

    func typeText(_ text: String) {
        guard !webView.isHidden else { return }
        // JSON serializes arbitrary user input as a safe JavaScript string literal.
        guard let data = try? JSONSerialization.data(withJSONObject: [text], options: [.fragmentsAllowed]),
              let json = String(data: data, encoding: .utf8) else { return }
        let js = "(function(){var s=\(json)[0];var e=document.activeElement; if(e && ('value' in e)){e.value=s;e.dispatchEvent(new Event('input',{bubbles:true}));e.dispatchEvent(new Event('change',{bubbles:true}));return true;}return false;})()"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Keep the car browser independent, but use the current URL for the next phone command.
        loadedURL = webView.url
    }
}
