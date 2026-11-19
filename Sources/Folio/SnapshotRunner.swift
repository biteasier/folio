import AppKit
import FolioCore

/// Renders a file to PNG (or PDF with --pdf) without showing a window.
/// Extra flags: --dark, --width N, --toc (contents sidebar), --source (Markdown source view). Used by Scripts/snapshot.sh
/// to check rendering and timing from the command line.
final class SnapshotRunner: NSObject {
    private let input: URL, output: URL, width: Double
    private let args = CommandLine.arguments
    private var flags: Set<String> { Set(args.filter { $0.hasPrefix("--") }) }
    private let page = PageController()
    private let window: NSWindow
    private let started = CFAbsoluteTimeGetCurrent()

    init(input: URL, output: URL, dark: Bool, width: Double) {
        self.input = input
        self.output = output
        self.width = width
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 800),
                          styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.backgroundColor = .folioBackground
        window.contentView = page.webView
        window.alphaValue = 0.01   // effectively invisible, but still rendered by WebKit
        window.ignoresMouseEvents = true
        super.init()
    }

    @objc func printDone(_ op: NSPrintOperation, success: Bool, context: UnsafeMutableRawPointer?) {
        let ok = success && FileManager.default.fileExists(atPath: output.path)
        print(ok ? "pdf written" : "pdf FAILED")
        exit(ok ? 0 : 1)
    }

    func start() {
        window.orderFrontRegardless()
        page.onLog = { FileHandle.standardError.write(Data("[js] \($0)\n".utf8)) }
        if flags.contains("--toc") { page.showsTOC = true }
        var toggledSource = false
        page.onRendered = { [self] parseMs in
            if flags.contains("--source") && !toggledSource { toggledSource = true; page.toggleSource(); return }
            if flags.contains("--pdf") {
                // Same call the Export as PDF menu item makes.
                page.prepareForPrint { [self] in
                    page.printOperation(saveTo: output).runModal(for: window, delegate: self,
                        didRun: #selector(SnapshotRunner.printDone(_:success:context:)), contextInfo: nil)
                }
                return
            }
            let renderMs = (CFAbsoluteTimeGetCurrent() - started) * 1000
            page.webView.evaluateJavaScript("document.documentElement.scrollHeight") { [self] h, _ in
                let height = min((h as? Double) ?? 800, 16000)
                window.setContentSize(NSSize(width: width, height: height))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [self] in
                    page.webView.takeSnapshot(with: nil) { [self] image, error in
                        guard let image, let tiff = image.tiffRepresentation,
                              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
                            print("snapshot failed: \(String(describing: error))"); exit(1)
                        }
                        try? png.write(to: output)
                        print(String(format: "parse %.2f ms · launch-to-rendered %.0f ms · %.0f px tall", parseMs, renderMs, height))
                        exit(0)
                    }
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { print("timed out"); exit(2) }
        guard let data = try? Data(contentsOf: input) else { print("cannot read \(input.path)"); exit(1) }
        page.display(TextDecoding.decode(data), baseURL: input, keepScroll: false)
    }
}

final class SnapshotDelegate: NSObject, NSApplicationDelegate {
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        sender.reply(toOpenOrPrint: .success)
    }
}
