import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Palette {
    static let bgTop = CGColor(red: 1.0 / 255.0, green: 22.0 / 255.0, blue: 35.0 / 255.0, alpha: 1.0)
    static let bgLow = CGColor(red: 7.0 / 255.0, green: 83.0 / 255.0, blue: 119.0 / 255.0, alpha: 1.0)
    static let glow = CGColor(red: 122.0 / 255.0, green: 220.0 / 255.0, blue: 255.0 / 255.0, alpha: 0.36)
    static let ripple = CGColor(red: 210.0 / 255.0, green: 247.0 / 255.0, blue: 255.0 / 255.0, alpha: 0.30)
    static let text = CGColor(red: 235.0 / 255.0, green: 253.0 / 255.0, blue: 255.0 / 255.0, alpha: 1.0)
}

func pickFont(size: CGFloat) -> CTFont {
    let candidates = [
        "AvenirNextCondensed-DemiBold",
        "AvenirNextCondensed-Bold",
        "AvenirNextCondensed-Regular",
        "HelveticaNeue-Bold",
    ]

    for name in candidates {
        let font = CTFontCreateWithName(name as CFString, size, nil)
        let postscript = CTFontCopyPostScriptName(font) as String
        if postscript.caseInsensitiveCompare("LastResort") != .orderedSame {
            return font
        }
    }

    return CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
}

func drawIcon(size: Int, outputURL: URL) throws {
    let width = size
    let height = size
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "IconGen", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create graphics context."])
    }

    let rect = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))

    // Base vertical gradient.
    let linearColors = [Palette.bgTop, Palette.bgLow] as CFArray
    let linearLocations: [CGFloat] = [0.0, 1.0]
    if let linear = CGGradient(colorsSpace: colorSpace, colors: linearColors, locations: linearLocations) {
        context.drawLinearGradient(
            linear,
            start: CGPoint(x: rect.midX, y: rect.maxY),
            end: CGPoint(x: rect.midX, y: rect.minY),
            options: []
        )
    }

    // Top-left glow, matching the app background accent.
    let glowCenter = CGPoint(x: rect.width * 0.2, y: rect.height * 0.9)
    let glowRadius = rect.width * 0.55
    let glowColors = [Palette.glow, CGColor(red: 0, green: 0, blue: 0, alpha: 0)] as CFArray
    let glowLocations: [CGFloat] = [0.0, 1.0]
    if let radial = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: glowLocations) {
        context.drawRadialGradient(
            radial,
            startCenter: glowCenter,
            startRadius: 0,
            endCenter: glowCenter,
            endRadius: glowRadius,
            options: []
        )
    }

    // Soft ripple rings.
    context.setStrokeColor(Palette.ripple)
    context.setLineWidth(rect.width * 0.008)
    context.strokeEllipse(in: CGRect(x: rect.width * 0.24, y: rect.height * 0.24, width: rect.width * 0.52, height: rect.height * 0.52))
    context.setStrokeColor(CGColor(red: 210.0 / 255.0, green: 247.0 / 255.0, blue: 255.0 / 255.0, alpha: 0.24))
    context.setLineWidth(rect.width * 0.006)
    context.strokeEllipse(in: CGRect(x: rect.width * 0.18, y: rect.height * 0.18, width: rect.width * 0.64, height: rect.height * 0.64))

    // "bpm" text.
    let font = pickFont(size: rect.width * 0.41)
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(rawValue: kCTFontAttributeName as String): font,
        NSAttributedString.Key(rawValue: kCTForegroundColorAttributeName as String): Palette.text,
    ]
    let text = NSAttributedString(string: "bpm", attributes: attributes)
    let line = CTLineCreateWithAttributedString(text)
    let bounds = CTLineGetBoundsWithOptions(line, [.useGlyphPathBounds, .useOpticalBounds])

    let x = rect.midX - bounds.width / 2.0 - bounds.minX
    let y = rect.midY - bounds.height / 2.0 - bounds.minY - rect.height * 0.02

    context.saveGState()
    context.setShadow(offset: .zero, blur: rect.width * 0.035, color: CGColor(red: 142.0 / 255.0, green: 239.0 / 255.0, blue: 255.0 / 255.0, alpha: 0.52))
    context.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(line, context)
    context.restoreGState()

    guard let image = context.makeImage() else {
        throw NSError(domain: "IconGen", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not export CGImage."])
    }

    guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "IconGen", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not create image destination."])
    }

    CGImageDestinationAddImage(destination, image, nil)
    if !CGImageDestinationFinalize(destination) {
        throw NSError(domain: "IconGen", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not finalize PNG output."])
    }
}

let outputDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("icons", isDirectory: true)
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let targets: [(String, Int)] = [
    ("icon-1024.png", 1024),
    ("icon-512.png", 512),
    ("icon-192.png", 192),
    ("apple-touch-icon.png", 180),
    ("favicon-32.png", 32),
]

for (filename, size) in targets {
    let url = outputDir.appendingPathComponent(filename)
    try drawIcon(size: size, outputURL: url)
    print("Wrote \(filename)")
}
