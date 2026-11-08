import AppKit

// Renders square menu bar icons that fill the 16pt macOS menu item height without clipping.
// Writes valid .icns files and preview PNGs for each style.
// Usage: swift render-menubar-icons.swift <output-dir>

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "menubar"
let styles = ["fr": "FR", "123": "123", "frpc": "FRPC", "dg": "DG", "digit": "DG"]

func render(text: String, px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: s, height: s)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.clear.set()
    NSRect(x: 0, y: 0, width: s, height: s).fill()

    NSColor.white.setFill()
    // Fill ~94% of the square canvas so the pill reaches ~15pt tall in a 16pt slot
    // without clipping the antialiased curved corners
    let boxSize = s * 0.94
    let origin = (s - boxSize) / 2
    let radius = boxSize * 0.25
    let box = NSBezierPath(
        roundedRect: NSRect(x: origin, y: origin, width: boxSize, height: boxSize),
        xRadius: radius, yRadius: radius)
    box.fill()

    let probe = NSFont.systemFont(ofSize: 100, weight: .semibold)
    let capPerPoint = probe.capHeight / 100
    let refSize = (boxSize * 0.49) / capPerPoint
    let font = NSFont.systemFont(ofSize: refSize, weight: .semibold)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
    let natural = (text as NSString).size(withAttributes: attrs)
    let maxTextWidth = boxSize * 0.88
    let scaleX = min(1, maxTextWidth / natural.width)
    let capY = (s - font.capHeight) / 2 + font.descender

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

func packICNS(chunks: [(tag: String, data: Data)]) -> Data {
    var body = Data()
    for (tag, data) in chunks {
        let tagData = tag.data(using: .ascii)!
        var len = UInt32(data.count + 8).bigEndian
        body.append(tagData)
        body.append(Data(bytes: &len, count: 4))
        body.append(data)
    }
    var full = "icns".data(using: .ascii)!
    var totalLen = UInt32(body.count + 8).bigEndian
    full.append(Data(bytes: &totalLen, count: 4))
    full.append(body)
    return full
}

let fm = FileManager.default
try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)

for (name, text) in styles {
    let p16 = render(text: text, px: 16)
    let p32 = render(text: text, px: 32)
    let p128 = render(text: text, px: 128)
    let p256 = render(text: text, px: 256)
    let p512 = render(text: text, px: 512)

    let icnsData = packICNS(chunks: [
        ("ic04", p16),
        ("ic11", p32),
        ("ic05", p32),
        ("ic07", p128),
        ("ic13", p256),
        ("ic08", p256),
        ("ic14", p512),
    ])

    let icnsPath = "\(outDir)/\(name).icns"
    try! icnsData.write(to: URL(fileURLWithPath: icnsPath))

    let set = "\(outDir)/\(name).iconset"
    try? fm.removeItem(atPath: set)
    try! fm.createDirectory(atPath: set, withIntermediateDirectories: true)
    try! p16.write(to: URL(fileURLWithPath: "\(set)/icon_16x16.png"))
    try! p32.write(to: URL(fileURLWithPath: "\(set)/icon_16x16@2x.png"))
    try! p128.write(to: URL(fileURLWithPath: "\(set)/icon_128x128.png"))
    try! p256.write(to: URL(fileURLWithPath: "\(set)/icon_128x128@2x.png"))
}
print("Rendered \(styles.count) menu bar styles (full-height square) to \(outDir)")
