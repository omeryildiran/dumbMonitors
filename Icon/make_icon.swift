// Draws the DumbMonitors app icon: two monitors, one on and one off.
// Usage: swift Icon/make_icon.swift <output.png>   (renders 1024x1024)

import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

// Background: macOS-style rounded square with a soft shadow and slate gradient.
let inset: CGFloat = 100
let tile = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
rgb(0x1E2433).setFill(); tilePath.fill()
ctx.restoreGState()
NSGradient(starting: rgb(0x3A4560), ending: rgb(0x161A26))!.draw(in: tilePath, angle: -90)

// One monitor: bezel, screen, neck, foot.
func monitor(x: CGFloat, on: Bool) {
    let w: CGFloat = 300, h: CGFloat = 214, y: CGFloat = 451
    let bezel = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: 26, yRadius: 26)
    rgb(on ? 0xE9EDF5 : 0x5A6378).setFill(); bezel.fill()

    let screenRect = NSRect(x: x + 18, y: y + 18, width: w - 36, height: h - 36)
    let screen = NSBezierPath(roundedRect: screenRect, xRadius: 12, yRadius: 12)
    if on {
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 60, color: rgb(0x5BC0FF, 0.8).cgColor)
        rgb(0x3DA9F5).setFill(); screen.fill()
        ctx.restoreGState()
        NSGradient(starting: rgb(0x7FD3FF), ending: rgb(0x2B7BE4))!.draw(in: screen, angle: -60)
    } else {
        rgb(0x0B0E15).setFill(); screen.fill()
        // Power symbol on the dark screen.
        let c = NSPoint(x: screenRect.midX, y: screenRect.midY)
        let r: CGFloat = 46
        let arc = NSBezierPath()
        arc.appendArc(withCenter: c, radius: r, startAngle: 125, endAngle: 415)
        let line = NSBezierPath()
        line.move(to: NSPoint(x: c.x, y: c.y + 10)); line.line(to: NSPoint(x: c.x, y: c.y + r + 14))
        for p in [arc, line] { p.lineWidth = 16; p.lineCapStyle = .round; rgb(0x6B7690).setStroke(); p.stroke() }
    }

    let stand = rgb(on ? 0xC9CFDC : 0x4A5266)
    stand.setFill()
    NSBezierPath(rect: NSRect(x: x + w / 2 - 24, y: y - 70, width: 48, height: 72)).fill()
    NSBezierPath(roundedRect: NSRect(x: x + w / 2 - 90, y: y - 92, width: 180, height: 30), xRadius: 15, yRadius: 15).fill()
}

monitor(x: 180, on: true)
monitor(x: 544, on: false)

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
