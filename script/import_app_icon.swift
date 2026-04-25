import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fputs("Usage: swift script/import_app_icon.swift <icon-export-directory>\n", stderr)
    exit(64)
}

let exportDirectory = URL(fileURLWithPath: arguments[1], isDirectory: true)
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("PomodoroBar/Resources", isDirectory: true)
let iconset = resources.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let variantsDirectory = resources.appendingPathComponent("AppIconSourceVariants", isDirectory: true)
let output = resources.appendingPathComponent("AppIcon.icns")
let defaultIcon = exportDirectory.appendingPathComponent("PomodoroBar-iOS-Default-1024x1024@1x.png")

guard let sourceImage = NSImage(contentsOf: defaultIcon) else {
    fputs("Could not load \(defaultIcon.path)\n", stderr)
    exit(66)
}

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

func renderIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    NSGraphicsContext.current?.imageInterpolation = .high
    NSColor.clear.setFill()
    NSRect(origin: .zero, size: image.size).fill()

    sourceImage.draw(
        in: NSRect(x: 0, y: 0, width: size, height: size),
        from: NSRect(origin: .zero, size: sourceImage.size),
        operation: .sourceOver,
        fraction: 1
    )

    return image
}

try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for item in images {
    try savePNG(renderIcon(size: item.pixels), to: iconset.appendingPathComponent(item.filename))
}

try? FileManager.default.removeItem(at: variantsDirectory)
try FileManager.default.createDirectory(at: variantsDirectory, withIntermediateDirectories: true)

let variantFiles = try FileManager.default.contentsOfDirectory(
    at: exportDirectory,
    includingPropertiesForKeys: nil
).filter { $0.pathExtension.lowercased() == "png" }

for file in variantFiles {
    try FileManager.default.copyItem(
        at: file,
        to: variantsDirectory.appendingPathComponent(file.lastPathComponent)
    )
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    fputs("iconutil failed for \(iconset.path)\n", stderr)
    exit(Int32(process.terminationStatus))
}

print("Imported \(output.path)")
