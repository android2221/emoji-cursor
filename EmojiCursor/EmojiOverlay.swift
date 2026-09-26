import AppKit
import QuartzCore

/// One transparent, click-through window per screen that draws the emoji
/// and its tail.
final class EmojiOverlay {
    private var windows: [NSWindow] = []
    private var emojiLayers: [CALayer] = []
    private var tailLayers: [[CALayer]] = []  // [screenIndex][tailSlot]

    /// Used to drive the display link.
    var primaryWindow: NSWindow? { windows.first }

    func build(emoji: String, size: CGFloat) {
        tearDown()
        let image = Self.render(emoji, size: size)
        let bounds = CGRect(origin: .zero, size: CGSize(width: size, height: size))

        for screen in NSScreen.screens {
            let window = NSWindow(contentRect: screen.frame, styleMask: .borderless,
                                  backing: .buffered, defer: false, screen: screen)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.overlayWindow)) + 1)
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.isReleasedWhenClosed = false

            let view = NSView(frame: screen.frame)
            view.wantsLayer = true
            window.contentView = view

            // Tail layers go in first so they draw behind the emoji.
            var screenTailLayers: [CALayer] = []
            for slot in 0..<TailTrail.maxSlots {
                let tailLayer = Self.makeEmojiLayer(image: image, bounds: bounds)
                tailLayer.opacity = 0
                tailLayer.transform = Self.tailTransform(slot: slot)
                view.layer?.addSublayer(tailLayer)
                screenTailLayers.append(tailLayer)
            }

            let layer = Self.makeEmojiLayer(image: image, bounds: bounds)
            // Subtle drop shadow for depth
            layer.shadowColor = NSColor.black.cgColor
            layer.shadowOpacity = 0.3
            layer.shadowOffset = CGSize(width: 0.5, height: -1)
            layer.shadowRadius = 2
            view.layer?.addSublayer(layer)

            window.orderFrontRegardless()
            windows.append(window)
            emojiLayers.append(layer)
            tailLayers.append(screenTailLayers)
        }
    }

    func tearDown() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        emojiLayers.removeAll()
        tailLayers.removeAll()
    }

    func setEmoji(_ emoji: String, size: CGFloat) {
        let image = Self.render(emoji, size: size)
        let bounds = CGRect(origin: .zero, size: CGSize(width: size, height: size))
        for layer in emojiLayers + tailLayers.joined() {
            layer.bounds = bounds
            layer.contents = image
        }
    }

    func setHidden(_ hidden: Bool) {
        withoutAnimation {
            emojiLayers.forEach { $0.opacity = hidden ? 0 : 1 }
            if hidden {
                tailLayers.joined().forEach { $0.opacity = 0 }
            }
        }
    }

    /// Place the emoji (in global screen coordinates) and its tail.
    func update(position: CGPoint, animation: AnimationState, aliveEnabled: Bool,
                tail: TailTrail, tailLength: Int) {
        let transform = Self.transform(for: animation, aliveEnabled: aliveEnabled)
        withoutAnimation {
            for (i, window) in windows.enumerated() {
                let origin = window.frame.origin
                emojiLayers[i].position = CGPoint(x: position.x - origin.x, y: position.y - origin.y)
                emojiLayers[i].transform = transform

                for (slot, layer) in tailLayers[i].enumerated() {
                    if let pos = tail.position(forSlot: slot, length: tailLength) {
                        layer.position = CGPoint(x: pos.x - origin.x, y: pos.y - origin.y)
                        layer.opacity = TailTrail.opacity(forSlot: slot, length: tailLength)
                    } else {
                        layer.opacity = 0
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func withoutAnimation(_ body: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        body()
        CATransaction.commit()
    }

    private static func makeEmojiLayer(image: CGImage?, bounds: CGRect) -> CALayer {
        let layer = CALayer()
        layer.bounds = bounds
        layer.anchorPoint = CGPoint(x: 0, y: 1)
        layer.contentsGravity = .resizeAspect
        layer.contents = image
        return layer
    }

    private static func tailTransform(slot: Int) -> CATransform3D {
        let scale = TailTrail.scale(forSlot: slot)
        return CATransform3DMakeScale(scale, scale, 1)
    }

    static func transform(for animation: AnimationState, aliveEnabled: Bool) -> CATransform3D {
        var t = CATransform3DIdentity
        if aliveEnabled {
            let alive = animation.alive
            t = CATransform3DTranslate(t, 0, alive.bobY, 0)
            t = CATransform3DScale(t, alive.scale, alive.scale, 1)
            t = CATransform3DRotate(t, alive.tilt, 0, 0, 1)
        }
        if let jiggle = animation.jiggle {
            t = CATransform3DTranslate(t, 0, jiggle.bounce, 0)
            t = CATransform3DRotate(t, jiggle.angle, 0, 0, 1)
            t = CATransform3DScale(t, 2.0 - jiggle.squash, jiggle.squash, 1)
        }
        return t
    }

    private static func render(_ emoji: String, size: CGFloat) -> CGImage? {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let str = NSAttributedString(string: emoji, attributes: [
                .font: NSFont.systemFont(ofSize: size * 0.85)
            ])
            let strSize = str.size()
            str.draw(at: NSPoint(x: (rect.width - strSize.width) / 2,
                                 y: (rect.height - strSize.height) / 2))
            return true
        }
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
