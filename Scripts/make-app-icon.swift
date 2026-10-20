// Draws the Track Kar app icon at every macOS size into the asset catalog.
// Usage: swift Scripts/make-app-icon.swift
import AppKit

let output = URL(fileURLWithPath: "TrackKar/Resources/Assets.xcassets/AppIcon.appiconset")

/// The full 1024 artwork, drawn at any pixel size.
func drawIcon(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: 1024, height: 1024)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high

    // macOS icon grid: an 824-point rounded square centered on a 1024 canvas.
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: body, xRadius: 186, yRadius: 186)

    // Soft drop shadow, as on other macOS app icons.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    NSColor.black.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Palette blue to violet, top-left to bottom-right.
    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0x3D / 255, green: 0x8C / 255, blue: 0xF0 / 255, alpha: 1),
        NSColor(srgbRed: 0x2A / 255, green: 0x78 / 255, blue: 0xD6 / 255, alpha: 1),
        NSColor(srgbRed: 0x62 / 255, green: 0x50 / 255, blue: 0xD6 / 255, alpha: 1),
    ])!
    gradient.draw(in: shape, angle: -55)

    // A gentle highlight across the top half.
    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.18), NSColor.white.withAlphaComponent(0)])!
        .draw(in: NSRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // White stopwatch, drawn as paths so it stays crisp at every size.
    let center = NSPoint(x: body.midX, y: body.midY - 30)
    let radius: CGFloat = 250
    NSColor.white.setStroke()
    NSColor.white.setFill()

    let ring = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    ring.lineWidth = 58
    ring.stroke()

    // Crown and its stem on top.
    NSBezierPath(roundedRect: NSRect(x: center.x - 70, y: center.y + radius + 52, width: 140, height: 56), xRadius: 22, yRadius: 22).fill()
    NSBezierPath(rect: NSRect(x: center.x - 24, y: center.y + radius + 10, width: 48, height: 50)).fill()

    // Side button at about 1–2 o'clock.
    let button = NSBezierPath(roundedRect: NSRect(x: -26, y: radius + 18, width: 52, height: 64), xRadius: 14, yRadius: 14)
    var rotation = AffineTransform(translationByX: center.x, byY: center.y)
    rotation.rotate(byDegrees: -45)
    button.transform(using: rotation)
    button.fill()

    // Hand pointing to about two o'clock, with a center cap.
    let hand = NSBezierPath()
    hand.move(to: center)
    hand.line(to: NSPoint(x: center.x + 118, y: center.y + 150))
    hand.lineWidth = 46
    hand.lineCapStyle = .round
    hand.stroke()
    NSBezierPath(ovalIn: NSRect(x: center.x - 40, y: center.y - 40, width: 80, height: 80)).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        let png = drawIcon(pixels: pixels).representation(using: .png, properties: [:])!
        try! png.write(to: output.appendingPathComponent(name))
        images.append(["idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try! json.write(to: output.appendingPathComponent("Contents.json"))
print("Wrote \(images.count) icon images to \(output.path)")
