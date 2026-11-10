import AppKit

// Generates AppIcon.icns with the terminal icon scaled up to eliminate any white background,
// rendered on a transparent canvas with standard macOS squircle rounding.

guard CommandLine.arguments.count > 2 else {
    print("Usage: make-app-icon <input-png> <output-icns>")
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]

guard let srcImage = NSImage(contentsOfFile: inputPath) else {
    print("Failed to load \(inputPath)")
    exit(1)
}

let scale: CGFloat = 1.30
let origW = srcImage.size.width
let origH = srcImage.size.height

func renderIcon(pixelSize: Int) -> Data {
    let s = CGFloat(pixelSize)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: s, height: s)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.clear.set()
    NSRect(x: 0, y: 0, width: s, height: s).fill()

    let radius = s * (224.0 / 1024.0)
    let squircle = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: s, height: s), xRadius: radius, yRadius: radius)
    squircle.addClip()

    let drawW = s * scale
    let drawH = s * scale
    let drawX = (s - drawW) / 2
    let drawY = (s - drawH) / 2

    srcImage.draw(in: NSRect(x: drawX, y: drawY, width: drawW, height: drawH))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for item in sizes {
    let pngData = renderIcon(pixelSize: item.px)
    try pngData.write(to: tempDir.appendingPathComponent(item.name))
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", tempDir.path, "-o", outputPath]
try task.run()
task.waitUntilExit()

try? FileManager.default.removeItem(at: tempDir)

if task.terminationStatus == 0 {
    print("Generated \(outputPath) successfully (no white background).")
} else {
    print("iconutil failed with exit code \(task.terminationStatus)")
    exit(1)
}
