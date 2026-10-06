import AppKit
import ImageIO
import UniformTypeIdentifiers

/// What the overlay draws: a single frame for an emoji or a still image,
/// several for an animated GIF or PNG.
struct CursorArt {
    var frames: [CGImage]
    /// Seconds each frame shows; empty for a still.
    var frameDurations: [Double] = []

    static let imageTypes: [UTType] = [.png, .jpeg, .gif]
    /// Plenty for the largest cursor size on a Retina screen.
    static let maxPixelSize = 256
    /// Keeps a long GIF from holding hundreds of frames in memory.
    static let maxFrames = 300

    var isAnimated: Bool { frames.count > 1 && frameDurations.count == frames.count }

    static func emoji(_ emoji: String, size: CGFloat) -> CursorArt {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let str = NSAttributedString(string: emoji, attributes: [
                .font: NSFont.systemFont(ofSize: size * 0.85)
            ])
            let strSize = str.size()
            str.draw(at: NSPoint(x: (rect.width - strSize.width) / 2,
                                 y: (rect.height - strSize.height) / 2))
            return true
        }
        let frame = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        return CursorArt(frames: frame.map { [$0] } ?? [])
    }

    /// Loads a PNG, JPEG or GIF, scaled down to `maxPixelSize`. Nil for any
    /// other kind of file, whatever its extension says.
    static func image(contentsOf url: URL) -> CursorArt? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let typeID = CGImageSourceGetType(source) as String?,
              let type = UTType(typeID),
              imageTypes.contains(where: { type.conforms(to: $0) }) else { return nil }

        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary

        var frames: [CGImage] = []
        var durations: [Double] = []
        for index in 0..<min(CGImageSourceGetCount(source), maxFrames) {
            guard let frame = CGImageSourceCreateThumbnailAtIndex(source, index, options) else { continue }
            frames.append(frame)
            durations.append(frameDuration(delay(in: source, at: index)))
        }
        guard !frames.isEmpty else { return nil }
        return CursorArt(frames: frames, frameDurations: frames.count > 1 ? durations : [])
    }

    /// Browsers treat a missing or near-zero delay as 0.1s; so do we, or
    /// such GIFs would spin far too fast.
    static func frameDuration(_ delay: Double?) -> Double {
        guard let delay, delay > 0.01 else { return 0.1 }
        return delay
    }

    private static func delay(in source: CGImageSource, at index: Int) -> Double? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any] else {
            return nil
        }
        // GIF, or animated PNG.
        let containers = [
            (kCGImagePropertyGIFDictionary, kCGImagePropertyGIFUnclampedDelayTime, kCGImagePropertyGIFDelayTime),
            (kCGImagePropertyPNGDictionary, kCGImagePropertyAPNGUnclampedDelayTime, kCGImagePropertyAPNGDelayTime),
        ]
        for (container, unclamped, clamped) in containers {
            guard let dict = properties[container as String] as? [String: Any] else { continue }
            if let value = dict[unclamped as String] as? Double, value > 0 { return value }
            if let value = dict[clamped as String] as? Double { return value }
        }
        return nil
    }
}
