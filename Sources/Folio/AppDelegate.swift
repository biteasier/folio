import AppKit

/// Folio has no Dock icon (LSUIElement). While it runs it shows an icon in the
/// menu bar, and it quits when its last window closes.
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let recentMenu = NSMenu(title: "Open Recent")

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.build()   // keeps the keyboard shortcuts working
        PageController.prewarm()            // start WebKit while AppKit finishes launching
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        // Opened with no file (and nothing restored): ask for one.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if NSDocumentController.shared.documents.isEmpty { self.showOpenPanel(quitIfCancelled: true) }
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { false }

    // MARK: Opening

    @objc func openDocument(_ sender: Any?) { showOpenPanel(quitIfCancelled: false) }

    private func showOpenPanel(quitIfCancelled: Bool) {
        NSApp.activate(ignoringOtherApps: true)
        NSDocumentController.shared.beginOpenPanel { urls in
            guard let urls, !urls.isEmpty else {
                if quitIfCancelled && NSDocumentController.shared.documents.isEmpty { NSApp.terminate(nil) }
                return
            }
            urls.forEach(Self.open)
        }
    }

    static func open(_ url: URL) {
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
            if let error { NSApp.presentError(error) }
        }
    }

    @objc private func openRecent(_ item: NSMenuItem) {
        if let url = item.representedObject as? URL { Self.open(url) }
    }

    // MARK: Menu bar icon

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let image = NSImage(systemSymbolName: "doc.richtext", accessibilityDescription: "Folio")
        image?.isTemplate = true
        item.button?.image = image
        item.button?.toolTip = "Folio"

        let menu = NSMenu()
        menu.addItem(withTitle: "Open…", action: #selector(openDocument(_:)), keyEquivalent: "o").target = self
        let recent = menu.addItem(withTitle: "Open Recent", action: nil, keyEquivalent: "")
        recent.submenu = recentMenu
        recentMenu.delegate = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "About Folio", action: #selector(about(_:)), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Quit Folio", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
        trace("status item: visible=\(item.isVisible) window=\(item.button?.window.map { "\($0.windowNumber) \($0.frame)" } ?? "none")")
    }

    @objc private func about(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === recentMenu else { return }
        menu.removeAllItems()
        let urls = NSDocumentController.shared.recentDocumentURLs
        for url in urls {
            let item = menu.addItem(withTitle: url.lastPathComponent, action: #selector(openRecent(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = url
            item.toolTip = url.path
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 16, height: 16)
            item.image = icon
        }
        if urls.isEmpty { menu.addItem(withTitle: "No Recent Files", action: nil, keyEquivalent: "").isEnabled = false }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Clear Menu", action: #selector(NSDocumentController.clearRecentDocuments(_:)), keyEquivalent: "")
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
