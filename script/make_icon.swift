import AppKit
import CoreGraphics
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("PomodoroBar/Resources", isDirectory: true)
let iconset = resources.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let output = resources.appendingPathComponent("AppIcon.icns")

try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

struct IconImage {
    let filename: String
    let pixels: CGFloat
}

let images = [
    IconImage(filename: "icon_16x16.png", pixels: 16),
    IconImage(filename: "icon_16x16@2x.png", pixels: 32),
    IconImage(filename: "icon_32x32.png", pixels: 32),
    IconImage(filename: "icon_32x32@2x.png", pixels: 64),
    IconImage(filename: "icon_128x128.png", pixels: 128),
    IconImage(filename: "icon_128x128@2x.png", pixels: 256),
    IconImage(filename: "icon_256x256.png", pixels: 256),
    IconImage(filename: "icon_256x256@2x.png", pixels: 512),
    IconImage(filename: "icon_512x512.png", pixels: 512),
    IconImage(filename: "icon_512x512@2x.png", pixels: 1024)
]

func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, scale: CGFloat) -> CGRect {
    CGRect(x: x * scale, y: y * scale, width: width * scale, height: height * scale)
}

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func savePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let data = bitmap.representation(using: .png, properties: [:])
    else {
        throw CocoaError(.fileWriteUnknown)
    }

    try data.write(to: url)
}

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    let scale = size / 1024

    image.lockFocus()
    defer { image.unlockFocus() }

    NSGraphicsContext.current?.imageInterpolation = .high

    let canvas = CGRect(origin: .zero, size: CGSize(width: size, height: size))
    color(0, 0, 0, 0).setFill()
    canvas.fill()

    let background = NSBezierPath(roundedRect: rect(80, 80, 864, 864, scale: scale), xRadius: 220 * scale, yRadius: 220 * scale)
    let gradient = NSGradient(colors: [
        color(255, 236, 210),
        color(255, 141, 116),
        color(238, 67, 86)
    ])!
    gradient.draw(in: background, angle: -35)

    NSColor.black.withAlphaComponent(0.18).setFill()
    NSBezierPath(ovalIn: rect(210, 700, 610, 100, scale: scale)).fill()

    let tomato = NSBezierPath()
    tomato.move(to: CGPoint(x: 512 * scale, y: 790 * scale))
    tomato.curve(to: CGPoint(x: 820 * scale, y: 510 * scale), controlPoint1: CGPoint(x: 700 * scale, y: 835 * scale), controlPoint2: CGPoint(x: 845 * scale, y: 690 * scale))
    tomato.curve(to: CGPoint(x: 512 * scale, y: 190 * scale), controlPoint1: CGPoint(x: 795 * scale, y: 305 * scale), controlPoint2: CGPoint(x: 675 * scale, y: 190 * scale))
    tomato.curve(to: CGPoint(x: 204 * scale, y: 510 * scale), controlPoint1: CGPoint(x: 350 * scale, y: 190 * scale), controlPoint2: CGPoint(x: 230 * scale, y: 305 * scale))
    tomato.curve(to: CGPoint(x: 512 * scale, y: 790 * scale), controlPoint1: CGPoint(x: 178 * scale, y: 690 * scale), controlPoint2: CGPoint(x: 325 * scale, y: 835 * scale))
    tomato.close()

    NSColor.black.withAlphaComponent(0.18).setFill()
    let shadow = tomato.copy() as! NSBezierPath
    shadow.transform(using: AffineTransform(translationByX: 0, byY: -18 * scale))
    shadow.fill()

    let tomatoGradient = NSGradient(colors: [
        color(255, 99, 91),
        color(216, 30, 62),
        color(153, 19, 47)
    ])!
    tomatoGradient.draw(in: tomato, angle: -70)

    NSColor.white.withAlphaComponent(0.22).setFill()
    NSBezierPath(ovalIn: rect(330, 585, 230, 145, scale: scale)).fill()

    let leaf = NSBezierPath()
    leaf.move(to: CGPoint(x: 512 * scale, y: 792 * scale))
    leaf.curve(to: CGPoint(x: 452 * scale, y: 900 * scale), controlPoint1: CGPoint(x: 470 * scale, y: 826 * scale), controlPoint2: CGPoint(x: 435 * scale, y: 862 * scale))
    leaf.curve(to: CGPoint(x: 552 * scale, y: 836 * scale), controlPoint1: CGPoint(x: 510 * scale, y: 902 * scale), controlPoint2: CGPoint(x: 546 * scale, y: 872 * scale))
    leaf.curve(to: CGPoint(x: 640 * scale, y: 890 * scale), controlPoint1: CGPoint(x: 590 * scale, y: 868 * scale), controlPoint2: CGPoint(x: 620 * scale, y: 882 * scale))
    leaf.curve(to: CGPoint(x: 596 * scale, y: 760 * scale), controlPoint1: CGPoint(x: 660 * scale, y: 840 * scale), controlPoint2: CGPoint(x: 640 * scale, y: 790 * scale))
    leaf.curve(to: CGPoint(x: 512 * scale, y: 792 * scale), controlPoint1: CGPoint(x: 565 * scale, y: 772 * scale), controlPoint2: CGPoint(x: 540 * scale, y: 782 * scale))
    leaf.close()
    NSGradient(colors: [color(86, 205, 112), color(19, 130, 76)])!.draw(in: leaf, angle: 65)

    let clockRect = rect(362, 362, 300, 300, scale: scale)
    NSColor.white.withAlphaComponent(0.94).setStroke()
    let ring = NSBezierPath(ovalIn: clockRect)
    ring.lineWidth = 40 * scale
    ring.stroke()

    NSColor.white.setStroke()
    let hand = NSBezierPath()
    hand.lineCapStyle = .round
    hand.lineWidth = 36 * scale
    hand.move(to: CGPoint(x: 512 * scale, y: 512 * scale))
    hand.line(to: CGPoint(x: 512 * scale, y: 610 * scale))
    hand.move(to: CGPoint(x: 512 * scale, y: 512 * scale))
    hand.line(to: CGPoint(x: 590 * scale, y: 462 * scale))
    hand.stroke()

    NSColor.white.setFill()
    NSBezierPath(ovalIn: rect(485, 485, 54, 54, scale: scale)).fill()

    return image
}

for item in images {
    let image = drawIcon(size: item.pixels)
    try savePNG(image, to: iconset.appendingPathComponent(item.filename))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw CocoaError(.fileWriteUnknown)
}

print("Generated \(output.path)")
