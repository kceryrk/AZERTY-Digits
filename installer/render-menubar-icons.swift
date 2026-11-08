import AppKit

// Renders the menu bar icon styles as black-on-transparent iconsets (16 and 32 px).
// Usage: swift render-menubar-icons.swift <output-dir>

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "menubar"
let styles = ["fr": "FR", "123": "123", "frpc": "FRPC", "digit": "DIGIT"]

func render(text: String, px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.clear.set()
    NSRect(x: 0, y: 0, width: s, height: s).fill()

    NSColor(calibratedWhite: 0.55, alpha: 1).setFill()
    let boxW = s * 0.96
    let boxH = s * 0.64
    let box = NSBezierPath(
        roundedRect: NSRect(x: (s - boxW) / 2, y: (s - boxH) / 2, width: boxW, height: boxH),
        xRadius: boxH * 0.25, yRadius: boxH * 0.25)
    box.fill()

    // Font size comes from "123" so every label has the same letter height.
    // Wider labels are squeezed horizontally to fit, never shrunk vertically.
    let probe = NSFont.systemFont(ofSize: 100, weight: .heavy)
    let capPerPoint = probe.capHeight / 100
    let refSize = (boxH * 0.66) / capPerPoint
    let font = NSFont.systemFont(ofSize: refSize, weight: .heavy)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
    let natural = (text as NSString).size(withAttributes: attrs)
    let scaleX = min(1, (boxW * 0.86) / natural.width)
    let capY = s / 2 - font.capHeight / 2 + font.descender

    // Knock the text out of the box so the menu bar shows through, as Apple's input icons do.
    let cg = NSGraphicsContext.current!.cgContext
    cg.setBlendMode(.clear)
    cg.saveGState()
    cg.translateBy(x: s / 2, y: 0)
    cg.scaleBy(x: scaleX, y: 1)
    cg.translateBy(x: -s / 2, y: 0)
    (text as NSString).draw(
        at: NSPoint(x: (s - natural.width) / 2, y: capY),
        withAttributes: attrs)
    cg.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
for (name, text) in styles {
    let set = "\(outDir)/\(name).iconset"
    try? fm.removeItem(atPath: set)
    try! fm.createDirectory(atPath: set, withIntermediateDirectories: true)
    try! render(text: text, px: 16).write(to: URL(fileURLWithPath: "\(set)/icon_16x16.png"))
    try! render(text: text, px: 32).write(to: URL(fileURLWithPath: "\(set)/icon_16x16@2x.png"))
    try! render(text: text, px: 128).write(to: URL(fileURLWithPath: "\(set)/icon_128x128.png"))
    try! render(text: text, px: 256).write(to: URL(fileURLWithPath: "\(set)/icon_128x128@2x.png"))
}
print("Rendered \(styles.count) menu bar styles to \(outDir)")
