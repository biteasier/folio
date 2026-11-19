import AppKit

let launchTime = CFAbsoluteTimeGetCurrent()

let app = NSApplication.shared
let args = CommandLine.arguments

if let i = args.firstIndex(of: "--snapshot"), i + 2 < args.count {
    // Test hook: Folio --snapshot in.md out.png [--dark] [--width N]
    app.setActivationPolicy(.accessory)
    let width = args.firstIndex(of: "--width").flatMap { $0 + 1 < args.count ? Double(args[$0 + 1]) : nil } ?? 900
    let runner = SnapshotRunner(input: URL(fileURLWithPath: args[i + 1]),
                                output: URL(fileURLWithPath: args[i + 2]),
                                dark: args.contains("--dark"), width: width)
    let quiet = SnapshotDelegate()   // stops AppKit treating the paths as files to open
    app.delegate = quiet
    runner.start()
    app.run()
} else {
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
