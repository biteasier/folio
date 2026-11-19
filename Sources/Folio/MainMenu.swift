import AppKit

enum MainMenu {
    static func build() -> NSMenu {
        let main = NSMenu()
        let name = ProcessInfo.processInfo.processName

        main.addSubmenu(name, [
            item("About \(name)", #selector(NSApplication.orderFrontStandardAboutPanel(_:))),
            .separator(),
            services(),
            .separator(),
            item("Hide \(name)", #selector(NSApplication.hide(_:)), "h"),
            item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]),
            item("Show All", #selector(NSApplication.unhideAllApplications(_:))),
            .separator(),
            item("Quit \(name)", #selector(NSApplication.terminate(_:)), "q"),
        ])

        main.addSubmenu("File", [
            item("Open…", #selector(AppDelegate.openDocument(_:)), "o"),
            openRecent(),
            .separator(),
            item("Close", #selector(NSWindow.performClose(_:)), "w"),
            item("Reveal in Finder", #selector(DocumentWindowController.revealInFinder(_:)), "r", [.command, .shift]),
            .separator(),
            item("Export as PDF…", #selector(DocumentWindowController.exportPDF(_:)), "e", [.command, .option]),
            item("Print…", #selector(DocumentWindowController.printPage(_:)), "p"),
        ])

        main.addSubmenu("Edit", [
            item("Copy", #selector(NSText.copy(_:)), "c"),
            item("Select All", #selector(NSText.selectAll(_:)), "a"),
            .separator(),
            submenu("Find", [
                item("Find…", #selector(DocumentWindowController.showFind(_:)), "f"),
                item("Find Next", #selector(DocumentWindowController.findNext(_:)), "g"),
                item("Find Previous", #selector(DocumentWindowController.findPrevious(_:)), "g", [.command, .shift]),
                item("Use Selection for Find", #selector(DocumentWindowController.useSelectionForFind(_:)), "e"),
            ]),
        ])

        main.addSubmenu("View", [
            item("Table of Contents", #selector(DocumentWindowController.toggleTOC(_:)), "t", [.command, .shift]),
            item("Markdown Source", #selector(DocumentWindowController.toggleSource(_:)), "u", [.command, .option]),
            .separator(),
            item("Reload", #selector(DocumentWindowController.reloadDocument(_:)), "r"),
            .separator(),
            item("Actual Size", #selector(DocumentWindowController.actualSize(_:)), "0"),
            item("Zoom In", #selector(DocumentWindowController.zoomIn(_:)), "+"),
            hidden(item("Zoom In", #selector(DocumentWindowController.zoomIn(_:)), "=")),
            item("Zoom Out", #selector(DocumentWindowController.zoomOut(_:)), "-"),
            .separator(),
            item("Show Toolbar", #selector(NSWindow.toggleToolbarShown(_:)), "t", [.command, .option]),
            item("Enter Full Screen", #selector(NSWindow.toggleFullScreen(_:)), "f", [.command, .control]),
        ])

        let window = NSMenu(title: "Window")
        [item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"),
         item("Zoom", #selector(NSWindow.performZoom(_:))),
         .separator(),
         item("Show Previous Tab", #selector(NSWindow.selectPreviousTab(_:)), "\t", [.control, .shift]),
         item("Show Next Tab", #selector(NSWindow.selectNextTab(_:)), "\t", [.control]),
         item("Merge All Windows", #selector(NSWindow.mergeAllWindows(_:))),
         .separator(),
         item("Bring All to Front", #selector(NSApplication.arrangeInFront(_:)))].forEach(window.addItem)
        NSApp.windowsMenu = window
        main.addItem(NSMenuItem(title: "Window", action: nil, keyEquivalent: "")).submenu = window

        let help = NSMenu(title: "Help")
        NSApp.helpMenu = help
        main.addItem(NSMenuItem(title: "Help", action: nil, keyEquivalent: "")).submenu = help
        return main
    }

    private static func item(_ title: String, _ action: Selector, _ key: String = "",
                             _ mods: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.keyEquivalentModifierMask = mods
        return i
    }

    private static func hidden(_ i: NSMenuItem) -> NSMenuItem {
        i.isHidden = true
        i.allowsKeyEquivalentWhenHidden = true
        return i
    }

    private static func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let menu = NSMenu(title: title)
        items.forEach(menu.addItem)
        let i = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        i.submenu = menu
        return i
    }

    private static func services() -> NSMenuItem {
        let i = submenu("Services", [])
        NSApp.servicesMenu = i.submenu
        return i
    }

    private static func openRecent() -> NSMenuItem {
        let i = submenu("Open Recent", [item("Clear Menu", #selector(NSDocumentController.clearRecentDocuments(_:)))])
        // AppKit fills a menu with this private name with recent documents.
        i.submenu?.perform(NSSelectorFromString("_setMenuName:"), with: "NSRecentDocumentsMenu")
        return i
    }
}

private extension NSMenu {
    func addSubmenu(_ title: String, _ items: [NSMenuItem]) {
        let menu = NSMenu(title: title)
        items.forEach(menu.addItem)
        addItem(NSMenuItem(title: title, action: nil, keyEquivalent: "")).submenu = menu
    }
}

private extension NSMenu {
    @discardableResult
    func addItem(_ item: NSMenuItem) -> NSMenuItem { insertItem(item, at: numberOfItems); return item }
}
