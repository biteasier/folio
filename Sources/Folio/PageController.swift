import AppKit
import WebKit
import FolioCore

enum WebResources {
    static let directory = Bundle.main.resourceURL!.appendingPathComponent("web", isDirectory: true)
    static let index = directory.appendingPathComponent("index.html")
}

/// Receives messages from app.js. Holds the page weakly to avoid a retain cycle
/// (WKUserContentController keeps its handlers alive).
final class ScriptBridge: NSObject, WKScriptMessageHandler {
    weak var page: PageController?
    var isReady = false

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        if type == "ready" { isReady = true }
        page?.handle(type, body)
    }
}

/// Owns one WKWebView showing one rendered Markdown document.
final class PageController: NSObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    private let bridge: ScriptBridge
    private var whenReady: [() -> Void] = []
    private var generation = 0
    private var text = ""
    private var baseURL: URL?
    private var pendingFragment: String?

    var onRendered: ((_ parseMs: Double) -> Void)?
    var onLog: ((String) -> Void)?
    private var lastParseMs = 0.0

    private(set) var showsSource = false
    /// Contents sidebar. Every window starts with it closed; not remembered.
    var showsTOC = false {
        didSet { call("folio.setTOC(on)", ["on": showsTOC]) }
    }

    private static let parseQueue = DispatchQueue(label: "folio.parse", qos: .userInitiated)
    private static var spare: (WKWebView, ScriptBridge)?

    /// Creates one web view ahead of time so the first window opens instantly.
    static func prewarm() { if spare == nil { spare = makeWebView() } }

    private static func makeWebView() -> (WKWebView, ScriptBridge) {
        let bridge = ScriptBridge()
        let config = WKWebViewConfiguration()
        config.userContentController.add(bridge, name: "folio")
        config.preferences.isTextInteractionEnabled = true
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 1000), configuration: config)
        webView.setValue(false, forKey: "drawsBackground")   // window colour shows through: no white flash
        webView.allowsMagnification = true
        // Read access to "/" so documents can show images from anywhere on disk.
        webView.loadFileURL(WebResources.index, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        trace("webview created")
        return (webView, bridge)
    }

    override init() {
        (webView, bridge) = Self.spare ?? Self.makeWebView()
        Self.spare = nil
        super.init()
        bridge.page = self
        webView.navigationDelegate = self
        webView.uiDelegate = self
        let zoom = UserDefaults.standard.double(forKey: "zoom")
        webView.pageZoom = zoom > 0 ? zoom : 1
    }

    // MARK: Rendering

    func display(_ text: String, baseURL: URL?, keepScroll: Bool) {
        self.text = text
        self.baseURL = baseURL
        generation += 1
        let gen = generation
        if showsSource {
            ready { self.call("return folio.showSource(text, keep)", ["text": text, "keep": keepScroll]) }
            return
        }
        Self.parseQueue.async {
            let t0 = CFAbsoluteTimeGetCurrent()
            let html = MarkdownRenderer.html(from: text)
            let ms = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            DispatchQueue.main.async {
                guard gen == self.generation else { return }   // a newer version is already on its way
                self.lastParseMs = ms
                self.ready {
                    self.call("return folio.render(html, base, opts)", [
                        "html": html,
                        "base": baseURL?.absoluteString ?? "",
                        "opts": ["keepScroll": keepScroll, "toc": self.showsTOC],
                    ])
                }
            }
        }
    }

    func toggleSource() {
        showsSource.toggle()
        display(text, baseURL: baseURL, keepScroll: false)
    }

    /// Scrolls to `#fragment` once the page has rendered.
    func reveal(fragment: String?) {
        guard let fragment, !fragment.isEmpty else { return }
        pendingFragment = fragment
        ready { self.call("folio.scrollToId(id)", ["id": fragment]) }
    }

    private func ready(_ work: @escaping () -> Void) {
        if bridge.isReady { work() } else { whenReady.append(work) }
    }

    private func call(_ js: String, _ args: [String: Any] = [:]) {
        webView.callAsyncJavaScript(js, arguments: args, in: nil, in: .page) { [weak self] result in
            if case .failure(let error) = result { self?.onLog?("JS error: \(error)") }
        }
    }


    func handle(_ type: String, _ body: [String: Any]) {
        trace(type)
        switch type {
        case "ready":
            let work = whenReady
            whenReady.removeAll()
            work.forEach { $0() }
        case "rendered":
            if let f = pendingFragment { pendingFragment = nil; call("folio.scrollToId(id)", ["id": f]) }
            onRendered?(lastParseMs)
        case "copy":
            if let text = body["text"] as? String {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
        case "log":
            onLog?(body["message"] as? String ?? "")
        default: break
        }
    }

    // MARK: Zoom, find, print

    func zoom(by factor: Double?) {
        let z = factor.map { min(max(webView.pageZoom * $0, 0.5), 3) } ?? 1
        webView.pageZoom = z
        UserDefaults.standard.set(Double(z), forKey: "zoom")
    }

    func find(_ string: String, backwards: Bool) {
        guard !string.isEmpty else { return }
        let config = WKFindConfiguration()
        config.backwards = backwards
        config.caseSensitive = false
        config.wraps = true
        webView.find(string, configuration: config) { result in
            if !result.matchFound { NSSound.beep() }
        }
    }

    func clearSelection() { webView.evaluateJavaScript("getSelection().removeAllRanges()") }

    /// Code is highlighted lazily as it scrolls into view; colour all of it first.
    func prepareForPrint(_ then: @escaping () -> Void) {
        webView.callAsyncJavaScript("await folio.highlightAll()", arguments: [:], in: nil, in: .page) { _ in then() }
    }

    func printOperation(saveTo url: URL? = nil) -> NSPrintOperation {
        let info = (NSPrintInfo.shared.copy() as! NSPrintInfo)
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isVerticallyCentered = false
        for side in [\NSPrintInfo.topMargin, \NSPrintInfo.bottomMargin] { info[keyPath: side] = 36 }
        for side in [\NSPrintInfo.leftMargin, \NSPrintInfo.rightMargin] { info[keyPath: side] = 36 }
        if let url {
            info.jobDisposition = .save
            info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = url
        }
        let op = webView.printOperation(with: info)
        op.view?.frame = webView.bounds
        if url != nil { op.showsPrintPanel = false; op.showsProgressPanel = false }
        return op
    }

    // MARK: Navigation: only the template loads here; links open elsewhere

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { trace("committed") }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { trace("finished") }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { return decisionHandler(.cancel) }
        if url.isFileURL, url.path == WebResources.index.path, action.navigationType != .linkActivated {
            return decisionHandler(.allow)
        }
        decisionHandler(.cancel)
        Self.open(url)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url { Self.open(url) }
        return nil
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        bridge.isReady = false
        webView.loadFileURL(WebResources.index, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        display(text, baseURL: baseURL, keepScroll: true)
    }

    /// Markdown links open in Folio, everything else in its default app.
    static func open(_ url: URL) {
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "javascript" || scheme == "about" { return }
        guard url.isFileURL else { NSWorkspace.shared.open(url); return }

        var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let fragment = parts?.fragment
        parts?.fragment = nil
        let file = parts?.url ?? url
        guard FileManager.default.fileExists(atPath: file.path) else { NSSound.beep(); return }

        if TextDecoding.markdownExtensions.contains(file.pathExtension.lowercased()) {
            NSDocumentController.shared.openDocument(withContentsOf: file, display: true) { doc, _, _ in
                (doc?.windowControllers.first as? DocumentWindowController)?.page.reveal(fragment: fragment)
            }
        } else {
            NSWorkspace.shared.open(file)
        }
    }
}

private let tracing = ProcessInfo.processInfo.environment["FOLIO_TRACE"] != nil
/// Set FOLIO_TRACE=1 to print startup and render timings to stderr.
func trace(_ what: String) {
    guard tracing else { return }
    FileHandle.standardError.write(Data(String(format: "%7.0f ms  %@\n", (CFAbsoluteTimeGetCurrent() - launchTime) * 1000, what).utf8))
}
