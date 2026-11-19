import AppKit
import FolioCore
import UniformTypeIdentifiers

extension NSColor {
    /// Matches the page background in style.css so the window never flashes.
    static let folioBackground = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.110, green: 0.110, blue: 0.118, alpha: 1)   // #1c1c1e
            : .white
    }
}

/// Agent apps have no visible menu bar, so send key shortcuts (⌘F, ⌘R, ⌘W…)
/// through the main menu explicitly.
final class FolioWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if NSApp.mainMenu?.performKeyEquivalent(with: event) == true { return true }
        return super.performKeyEquivalent(with: event)
    }
}

private extension NSToolbarItem.Identifier {
    static let toc = Self("toc"), source = Self("source"), search = Self("search")
}

final class DocumentWindowController: NSWindowController, NSToolbarDelegate, NSSearchFieldDelegate, NSMenuItemValidation {
    let page = PageController()
    private var watcher: FileWatcher?
    private var searchItem: NSSearchToolbarItem?
    private var lastQuery = ""

    private var markdown: MarkdownDocument? { document as? MarkdownDocument }

    init() {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 900)
        let size = NSSize(width: min(920, screen.width - 80), height: min(1040, screen.height - 60))
        let window = FolioWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.minSize = NSSize(width: 360, height: 240)
        window.backgroundColor = .folioBackground
        window.titlebarAppearsTransparent = true   // title bar takes the page colour: one surface
        window.tabbingMode = .preferred
        window.tabbingIdentifier = "FolioDocument"
        window.contentView = page.webView
        window.center()
        super.init(window: window)
        shouldCascadeWindows = true
        windowFrameAutosaveName = "FolioDocument"

        let toolbar = NSToolbar(identifier: "FolioToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        window.toolbarStyle = .unified
    }

    required init?(coder: NSCoder) { fatalError() }

    func start() {
        guard let doc = markdown else { return }
        page.display(doc.text, baseURL: doc.fileURL, keepScroll: false)
        watcher = FileWatcher(url: { [weak self] in self?.markdown?.fileURL }) { [weak self] in
            self?.reloadFromDisk()
        }
        window?.makeFirstResponder(page.webView)
        NSApp.activate(ignoringOtherApps: true)

        // Test hook: FOLIO_TEST_CLOSE=1 presses the close button once the page has rendered.
        if ProcessInfo.processInfo.environment["FOLIO_TEST_CLOSE"] != nil {
            page.onRendered = { [weak self] _ in
                trace("test: closing window")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.window?.performClose(nil) }
            }
        }
    }

    private func reloadFromDisk(keepScroll: Bool = true) {
        guard let url = markdown?.fileURL else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let data = try? Data(contentsOf: url) else { return }
            let text = TextDecoding.decode(data)
            DispatchQueue.main.async {
                guard let self, let doc = self.markdown else { return }
                doc.text = text
                self.page.display(text, baseURL: url, keepScroll: keepScroll)
            }
        }
    }

    // MARK: Actions (reached through the responder chain from the menu)

    @objc func reloadDocument(_ sender: Any?) { reloadFromDisk() }
    @objc func toggleTOC(_ sender: Any?) { page.showsTOC.toggle() }
    @objc func toggleSource(_ sender: Any?) { page.toggleSource() }
    @objc func zoomIn(_ sender: Any?) { page.zoom(by: 1.1) }
    @objc func zoomOut(_ sender: Any?) { page.zoom(by: 1 / 1.1) }
    @objc func actualSize(_ sender: Any?) { page.zoom(by: nil) }

    @objc func showFind(_ sender: Any?) {
        guard let window else { return }
        window.toolbar?.isVisible = true
        searchItem?.beginSearchInteraction()
        window.makeFirstResponder(searchItem?.searchField)
    }
    @objc func findNext(_ sender: Any?) { lastQuery.isEmpty ? showFind(nil) : page.find(lastQuery, backwards: false) }
    @objc func findPrevious(_ sender: Any?) { lastQuery.isEmpty ? showFind(nil) : page.find(lastQuery, backwards: true) }
    @objc func useSelectionForFind(_ sender: Any?) {
        page.webView.evaluateJavaScript("getSelection().toString()") { [weak self] value, _ in
            guard let self, let s = value as? String, !s.isEmpty else { return }
            self.lastQuery = s
            self.searchItem?.searchField.stringValue = s
        }
    }

    @objc func revealInFinder(_ sender: Any?) {
        if let url = markdown?.fileURL { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }

    @objc func printPage(_ sender: Any?) {
        guard let window else { return }
        page.prepareForPrint { [self] in
            page.printOperation().runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        }
    }

    @objc func exportPDF(_ sender: Any?) {
        guard let window else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = (markdown?.fileURL?.deletingPathExtension().lastPathComponent ?? "Document") + ".pdf"
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            self.page.prepareForPrint {
                self.page.printOperation(saveTo: url).runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
            }
        }
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(toggleTOC(_:)): item.state = page.showsTOC ? .on : .off
        case #selector(toggleSource(_:)): item.state = page.showsSource ? .on : .off
        default: break
        }
        return true
    }

    // MARK: Search field

    @objc private func searchChanged(_ field: NSSearchField) {
        let q = field.stringValue
        let again = q == lastQuery
        lastQuery = q
        if q.isEmpty { page.clearSelection() } else { page.find(q, backwards: again && NSEvent.modifierFlags.contains(.shift)) }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if selector == #selector(NSResponder.cancelOperation(_:)) {
            searchItem?.endSearchInteraction()
            window?.makeFirstResponder(page.webView)
            return true
        }
        return false
    }

    // MARK: Toolbar

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toc, .flexibleSpace, .source, .search]
    }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toc, .source, .search, .flexibleSpace, .space]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch id {
        case .search:
            let item = NSSearchToolbarItem(itemIdentifier: id)
            item.searchField.placeholderString = "Find"
            item.searchField.sendsSearchStringImmediately = true
            item.searchField.target = self
            item.searchField.action = #selector(searchChanged(_:))
            item.searchField.delegate = self
            searchItem = item
            return item
        case .toc:
            return button(id, "Contents", "sidebar.left", #selector(toggleTOC(_:)))
        case .source:
            return button(id, "Source", "chevron.left.forwardslash.chevron.right", #selector(toggleSource(_:)))
        default:
            return nil
        }
    }

    private func button(_ id: NSToolbarItem.Identifier, _ label: String, _ symbol: String, _ action: Selector) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: id)
        item.label = label
        item.toolTip = label
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        item.isBordered = true
        item.target = self
        item.action = action
        return item
    }
}
