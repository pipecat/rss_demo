import AppKit
import Foundation

let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let transform = AffineTransform(scale: CGFloat(pixels) / 1024)
        (transform as NSAffineTransform).concat()
        NSColor(srgbRed: 0.20, green: 0.36, blue: 0.29, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 35, y: 35, width: 954, height: 954), xRadius: 210, yRadius: 210).fill()
        NSColor(srgbRed: 0.35, green: 0.51, blue: 0.41, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 235, y: 215, width: 580, height: 620), xRadius: 42, yRadius: 42).fill()
        NSColor(srgbRed: 0.95, green: 0.95, blue: 0.88, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 200, y: 180, width: 580, height: 620), xRadius: 42, yRadius: 42).fill()
        NSColor(srgbRed: 0.24, green: 0.43, blue: 0.34, alpha: 1).setFill()
        for (y, width) in [(660, 210), (555, 360), (465, 360), (375, 275)] {
            NSBezierPath(roundedRect: NSRect(x: 290, y: y, width: width, height: 32), xRadius: 16, yRadius: 16).fill()
        }
        let mark = NSBezierPath(); mark.move(to: NSPoint(x: 640, y: 800)); mark.line(to: NSPoint(x: 710, y: 800)); mark.line(to: NSPoint(x: 710, y: 645)); mark.line(to: NSPoint(x: 675, y: 675)); mark.line(to: NSPoint(x: 640, y: 645)); mark.close(); mark.fill()
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let filename = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(filename))
    }
}
