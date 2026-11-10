import AppKit

// Renders square menu bar icons that fill the 16pt macOS menu item height without clipping.
// Writes valid .icns files for both light (black icon) and dark (white icon) modes.
// Usage: swift render-menubar-icons.swift <output-dir>

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "menubar"
let styles = [
    "fr": "FR",
    "be": "BE",
    "lu": "LU",
    "ma": "MA",
    "dz": "DZ",
    "dg": "DG",
    "123": "123",
    "frpc": "FRPC",
    "digit": "DG",
    // 1-letter versions
    "f": "F",
    "b": "B",
    "l": "L",
    "m": "M",
    "d": "D",
    // App icon styled as terminal prompt
    "app": ">_"
]

func render(text: String, px: Int, isBlack: Bool) -> Data {
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

    if isBlack {
        NSColor.black.setFill()
    } else {
        NSColor.white.setFill()
    }

    // Soft rectangle pill: 16x13 pt ratio (0.8125 height) for distinct pill styling
    let boxWidth = s
    let boxHeight = round(s * 0.8125)
    let originX: CGFloat = 0
    let originY = (s - boxHeight) / 2
    let radius = boxHeight * 0.22
    let box = NSBezierPath(
        roundedRect: NSRect(x: originX, y: originY, width: boxWidth, height: boxHeight),
        xRadius: radius, yRadius: radius)
    box.fill()

    let cg = NSGraphicsContext.current!.cgContext
    cg.saveGState()
    cg.setBlendMode(.clear)

    if text == ">_" {
        let font = NSFont.monospacedSystemFont(ofSize: boxHeight * 0.52, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let natural = (text as NSString).size(withAttributes: attrs)
        let capY = originY + (boxHeight - font.capHeight) / 2 + font.descender
        (text as NSString).draw(
            at: NSPoint(x: (s - natural.width) / 2, y: capY),
            withAttributes: attrs)
    } else {
        let probe = NSFont.systemFont(ofSize: 100, weight: .bold)
        let capPerPoint = probe.capHeight / 100
        let refSize = (boxHeight * 0.52) / capPerPoint
        let font = NSFont.systemFont(ofSize: refSize, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let natural = (text as NSString).size(withAttributes: attrs)
        let maxTextWidth = boxWidth * 0.84
        let scaleX = min(1, maxTextWidth / natural.width)
        let capY = originY + (boxHeight - font.capHeight) / 2 + font.descender

        cg.translateBy(x: s / 2, y: 0)
        cg.scaleBy(x: scaleX, y: 1)
        cg.translateBy(x: -s / 2, y: 0)
        (text as NSString).draw(
            at: NSPoint(x: (s - natural.width) / 2, y: capY),
            withAttributes: attrs)
    }
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
    for isBlack in [false, true] {
        let suffix = isBlack ? "-black" : ""
        let p16 = render(text: text, px: 16, isBlack: isBlack)
        let p32 = render(text: text, px: 32, isBlack: isBlack)
        let p128 = render(text: text, px: 128, isBlack: isBlack)
        let p256 = render(text: text, px: 256, isBlack: isBlack)
        let p512 = render(text: text, px: 512, isBlack: isBlack)

        let icnsData = packICNS(chunks: [
            ("ic04", p16),
            ("ic11", p32),
            ("ic05", p32),
            ("ic07", p128),
            ("ic13", p256),
            ("ic08", p256),
            ("ic14", p512),
        ])

        let icnsPath = "\(outDir)/\(name)\(suffix).icns"
        try! icnsData.write(to: URL(fileURLWithPath: icnsPath))

    }
}

print("Rendered white and black menu bar styles to \(outDir)")
