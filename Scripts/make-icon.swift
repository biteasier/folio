//
//  make-icon.swift — draws Folio's icon from code (no binary art in git).
//  Usage: swift Scripts/make-icon.swift <out-dir>   → <out-dir>/Folio.iconset
//
//  A white folded-corner page carrying the Markdown "M↓" mark, on a deep
//  blue squircle.
//
import AppKit

func squircle(_ r: NSRect, n: Double = 5) -> NSBezierPath {
    let p = NSBezierPath()
    for i in 0...720 {
        let t = 2 * Double.pi * Double(i) / 720, c = cos(t), s = sin(t)
        let pt = NSPoint(x: r.midX + r.width / 2 * copysign(pow(abs(c), 2 / n), c),
                         y: r.midY + r.height / 2 * copysign(pow(abs(s), 2 / n), s))
        i == 0 ? p.move(to: pt) : p.line(to: pt)
    }
    p.close()
    return p
}

func rgb(_ h: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(h >> 16 & 255) / 255, green: CGFloat(h >> 8 & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: a)
}

func draw(_ size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let k = size / 1024
    func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect { NSRect(x: x * k, y: y * k, width: w * k, height: h * k) }

    // Background
    let bg = squircle(R(100, 100, 824, 824))
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowBlurRadius = 24 * k; shadow.shadowOffset = NSSize(width: 0, height: -10 * k)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3); shadow.set()
    rgb(0x1B4FD8).setFill(); bg.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors: [rgb(0x3B82F6), rgb(0x1E3A8A)])!.draw(in: bg, angle: -90)

    // Page with a folded top-right corner
    let x0: CGFloat = 262, y0: CGFloat = 196, w: CGFloat = 500, h: CGFloat = 632, fold: CGFloat = 130, rad: CGFloat = 36
    let page = NSBezierPath()
    page.move(to: NSPoint(x: (x0 + rad) * k, y: y0 * k))
    page.line(to: NSPoint(x: (x0 + w - rad) * k, y: y0 * k))
    page.appendArc(withCenter: NSPoint(x: (x0 + w - rad) * k, y: (y0 + rad) * k), radius: rad * k, startAngle: 270, endAngle: 0)
    page.line(to: NSPoint(x: (x0 + w) * k, y: (y0 + h - fold) * k))
    page.line(to: NSPoint(x: (x0 + w - fold) * k, y: (y0 + h) * k))
    page.line(to: NSPoint(x: (x0 + rad) * k, y: (y0 + h) * k))
    page.appendArc(withCenter: NSPoint(x: (x0 + rad) * k, y: (y0 + h - rad) * k), radius: rad * k, startAngle: 90, endAngle: 180)
    page.line(to: NSPoint(x: x0 * k, y: (y0 + rad) * k))
    page.appendArc(withCenter: NSPoint(x: (x0 + rad) * k, y: (y0 + rad) * k), radius: rad * k, startAngle: 180, endAngle: 270)
    page.close()
    NSGraphicsContext.saveGraphicsState()
    let ps = NSShadow(); ps.shadowBlurRadius = 30 * k; ps.shadowOffset = NSSize(width: 0, height: -14 * k)
    ps.shadowColor = NSColor.black.withAlphaComponent(0.35); ps.set()
    NSColor.white.setFill(); page.fill()
    NSGraphicsContext.restoreGraphicsState()

    let flap = NSBezierPath()
    flap.move(to: NSPoint(x: (x0 + w - fold) * k, y: (y0 + h) * k))
    flap.line(to: NSPoint(x: (x0 + w - fold) * k, y: (y0 + h - fold + 22) * k))
    flap.appendArc(withCenter: NSPoint(x: (x0 + w - fold + 22) * k, y: (y0 + h - fold + 22) * k), radius: 22 * k, startAngle: 180, endAngle: 270)
    flap.line(to: NSPoint(x: (x0 + w) * k, y: (y0 + h - fold) * k))
    flap.close()
    rgb(0xC7D2FE).setFill(); flap.fill()

    // Text lines
    rgb(0xCBD5E1).setFill()
    for (i, lw) in [300, 360, 240].enumerated() {
        NSBezierPath(roundedRect: R(x0 + 70, y0 + 120 - CGFloat(i) * 0 + CGFloat(2 - i) * 52 - 52, CGFloat(lw), 22), xRadius: 11 * k, yRadius: 11 * k).fill()
    }

    // Markdown mark: "M" and a down arrow, inside a rounded outline
    let ink = rgb(0x1E3A8A)
    let box = NSBezierPath(roundedRect: R(x0 + 60, y0 + 270, 380, 230), xRadius: 34 * k, yRadius: 34 * k)
    box.lineWidth = 26 * k; ink.setStroke(); box.stroke()
    let m = NSBezierPath()
    m.lineWidth = 42 * k; m.lineCapStyle = .round; m.lineJoinStyle = .round
    let mx = x0 + 120, my = y0 + 330, mh: CGFloat = 112
    m.move(to: NSPoint(x: mx * k, y: my * k))
    m.line(to: NSPoint(x: mx * k, y: (my + mh) * k))
    m.line(to: NSPoint(x: (mx + 58) * k, y: (my + mh - 56) * k))
    m.line(to: NSPoint(x: (mx + 116) * k, y: (my + mh) * k))
    m.line(to: NSPoint(x: (mx + 116) * k, y: my * k))
    m.stroke()
    let ax = x0 + 350
    let arrow = NSBezierPath()
    arrow.lineWidth = 42 * k; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
    arrow.move(to: NSPoint(x: ax * k, y: (my + mh) * k)); arrow.line(to: NSPoint(x: ax * k, y: (my + 6) * k))
    arrow.move(to: NSPoint(x: (ax - 46) * k, y: (my + 50) * k)); arrow.line(to: NSPoint(x: ax * k, y: (my + 4) * k))
    arrow.line(to: NSPoint(x: (ax + 46) * k, y: (my + 50) * k))
    arrow.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let set = out.appendingPathComponent("Folio.iconset")
try? FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try! draw(CGFloat(base * scale)).representation(using: .png, properties: [:])!.write(to: set.appendingPathComponent(name))
    }
}
try! draw(1024).representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent("icon-1024.png"))
