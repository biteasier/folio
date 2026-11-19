import AppKit
import FolioCore

/// A read-only Markdown file. NSDocument gives Open, Open Recent, tabs,
/// window restoration and Finder integration for free.
final class MarkdownDocument: NSDocument {
    var text = ""

    override class var autosavesInPlace: Bool { false }
    override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool { true }
    override var isDocumentEdited: Bool { false }

    override func read(from data: Data, ofType typeName: String) throws {
        text = TextDecoding.decode(data)
    }

    override func data(ofType typeName: String) throws -> Data {
        throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError)
    }

    override func makeWindowControllers() {
        let controller = DocumentWindowController()
        addWindowController(controller)
        controller.start()
    }

    /// Closing the last document quits Folio (it has no Dock icon to come back to).
    override func close() {
        super.close()
        DispatchQueue.main.async {
            if NSDocumentController.shared.documents.isEmpty, NSApp.delegate is AppDelegate { NSApp.terminate(nil) }
        }
    }

    // The window controller watches the file itself, so ignore AppKit's own
    // change handling (it would otherwise try to revert or warn).
    override func presentedItemDidChange() {}
}
