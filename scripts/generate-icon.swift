import AppKit
import SwiftUI

@main
struct IconGenerator {
    @MainActor static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            throw NSError(domain: "SillageIcon", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Expected an iconset output directory."])
        }
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for size in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let pixels = size * scale
                let image = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                let context = NSGraphicsContext(bitmapImageRep: image)!
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = context
                let cg = context.cgContext
                cg.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
                cg.translateBy(x: 0, y: 1024)
                cg.scaleBy(x: 1, y: -1)
                cg.setFillColor(NSColor.black.cgColor)
                cg.addPath(CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824),
                                  cornerWidth: 184, cornerHeight: 184, transform: nil))
                cg.fillPath()
                cg.setStrokeColor(NSColor(SillageBrand.mint).cgColor)
                // Preserve the waveform at small Dock and Finder sizes.
                cg.setLineWidth(pixels <= 32 ? 34 : 22)
                cg.setLineCap(.round)
                cg.setLineJoin(.round)
                cg.addPath(SillageMark().path(in: CGRect(x: 222, y: 292, width: 580, height: 440)).cgPath)
                cg.strokePath()
                NSGraphicsContext.restoreGraphicsState()
                let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
                guard let data = image.representation(using: .png, properties: [:]) else {
                    throw NSError(domain: "SillageIcon", code: 2)
                }
                try data.write(to: directory.appendingPathComponent(name))
            }
        }
    }
}
