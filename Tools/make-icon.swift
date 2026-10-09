import AppKit

// Draws the chosen icon direction (1i): a server rack with a stitched amber patch.
func hex(_ v: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px) / 1024
    func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect { NSRect(x: x * s, y: y * s, width: w * s, height: h * s) }

    // macOS icon grid: an 824pt rounded square centred in 1024, with a soft drop shadow.
    let plate = NSBezierPath(roundedRect: r(100, 100, 824, 824), xRadius: 185 * s, yRadius: 185 * s)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(srgbRed: 0.24, green: 0.16, blue: 0.08, alpha: 0.3)
    shadow.shadowBlurRadius = 24 * s
    shadow.shadowOffset = NSSize(width: 0, height: -10 * s)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    hex(0x2B2622).setFill()
    plate.fill()
    NSGraphicsContext.restoreGraphicsState()

    // A warm top-to-bottom gradient and a light rim keep the dark plate readable on a dark Dock.
    NSGradient(starting: hex(0x4C433C), ending: hex(0x2B2622))!.draw(in: plate, angle: -90)
    let rim = NSBezierPath(roundedRect: r(100, 100, 824, 824).insetBy(dx: 3 * s, dy: 3 * s), xRadius: 182 * s, yRadius: 182 * s)
    rim.lineWidth = 6 * s
    NSColor(white: 1, alpha: 0.22).setStroke()
    rim.stroke()

    // The rack fills the whole plate: three units, top to bottom (y is bottom-up)
    let unitX: CGFloat = 215, unitW: CGFloat = 594, unitH: CGFloat = 156, gap: CGFloat = 62
    let bottomY: CGFloat = 216
    for i in 0..<3 {
        let y = bottomY + CGFloat(i) * (unitH + gap)
        let unit = NSBezierPath(roundedRect: r(unitX, y, unitW, unitH), xRadius: 36 * s, yRadius: 36 * s)
        if i == 1 {
            hex(0xDC701C).setFill()
            unit.fill()
            if px >= 128 {
                let stitch = NSBezierPath(roundedRect: r(unitX + 32, y + 32, unitW - 64, unitH - 64), xRadius: 12 * s, yRadius: 12 * s)
                stitch.lineWidth = 13 * s
                stitch.setLineDash([38 * s, 26 * s], count: 2, phase: 0)
                hex(0xFFF2DF).setStroke()
                stitch.stroke()
            }
        } else {
            hex(0x1F1B18).setFill()
            unit.fill()
            if px >= 64 {
                hex(0x81CE70).setFill()
                NSBezierPath(ovalIn: r(unitX + unitW - 96, y + unitH / 2 - 21, 42, 42)).fill()
            }
        }
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let out = URL(fileURLWithPath: CommandLine.arguments[1])
for px in [16, 32, 64, 128, 256, 512, 1024] {
    try render(px).write(to: out.appendingPathComponent("icon_\(px).png"))
}
