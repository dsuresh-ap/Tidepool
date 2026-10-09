// Draws the Tidepool app icon. Usage: swift scripts/make-icon.swift <output.png>
import AppKit

let size = 1024.0
let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
    let context = NSGraphicsContext.current!.cgContext
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    // Deep water.
    let water = CGGradient(colorsSpace: colorSpace, colors: [
        CGColor(srgbRed: 0.03, green: 0.26, blue: 0.31, alpha: 1),
        CGColor(srgbRed: 0.06, green: 0.48, blue: 0.52, alpha: 1),
    ] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(water, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size, y: size), options: [])

    // Faint dot grid, like the preview canvas.
    context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.10))
    stride(from: 64.0, to: size, by: 64).forEach { x in
        stride(from: 64.0, to: size, by: 64).forEach { y in
            context.fillEllipse(in: CGRect(x: x - 5, y: y - 5, width: 10, height: 10))
        }
    }

    // Tide line across the bottom.
    let tide = CGMutablePath()
    tide.move(to: CGPoint(x: 0, y: 250))
    tide.addCurve(to: CGPoint(x: size, y: 230), control1: CGPoint(x: 300, y: 340), control2: CGPoint(x: 640, y: 130))
    tide.addLine(to: CGPoint(x: size, y: 0))
    tide.addLine(to: CGPoint(x: 0, y: 0))
    tide.closeSubpath()
    context.addPath(tide)
    context.setFillColor(CGColor(srgbRed: 0.25, green: 0.72, blue: 0.76, alpha: 0.55))
    context.fillPath()

    // A small diagram: one node that branches to two.
    let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
    let top = CGRect(x: 352, y: 640, width: 320, height: 150)
    let left = CGRect(x: 170, y: 350, width: 280, height: 140)
    let right = CGRect(x: 574, y: 350, width: 280, height: 140)

    context.setStrokeColor(white)
    context.setLineWidth(26)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    for target in [left, right] {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: top.midX, y: top.minY))
        path.addLine(to: CGPoint(x: top.midX, y: 565))
        path.addLine(to: CGPoint(x: target.midX, y: 565))
        path.addLine(to: CGPoint(x: target.midX, y: target.maxY + 34))
        context.addPath(path)
        context.strokePath()
        // Arrow head.
        let head = CGMutablePath()
        head.move(to: CGPoint(x: target.midX - 34, y: target.maxY + 46))
        head.addLine(to: CGPoint(x: target.midX, y: target.maxY + 8))
        head.addLine(to: CGPoint(x: target.midX + 34, y: target.maxY + 46))
        context.addPath(head)
        context.strokePath()
    }

    context.setFillColor(white)
    for node in [top, left, right] {
        context.addPath(CGPath(roundedRect: node, cornerWidth: 38, cornerHeight: 38, transform: nil))
        context.fillPath()
    }
    // Accent on the top node.
    context.setFillColor(CGColor(srgbRed: 0.06, green: 0.48, blue: 0.52, alpha: 1))
    context.fillEllipse(in: CGRect(x: top.midX - 30, y: top.midY - 30, width: 60, height: 60))
    return true
}

let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
