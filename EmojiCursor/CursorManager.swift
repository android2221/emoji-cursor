import AppKit
import Combine

// MARK: - CursorManager

/// Manages the emoji cursor overlay. Replaces the system cursor by:
///   1. Hiding the real cursor with NSCursor.hide()
///   2. Showing a transparent full-screen overlay window that draws the
///      selected emoji at the live mouse position.
///
/// Clicks pass through the overlay (ignoresMouseEvents = true), so the
/// underlying OS click-handling is unaffected.
final class CursorManager: ObservableObject {
    static let shared = CursorManager()

    @Published private(set) var isActive = false
    @Published private(set) var currentEmoji: String = UserDefaults.standard.string(forKey: "lastEmoji") ?? "😀"

    /// Called whenever the active emoji changes (used to sync the status bar icon).
    var onEmojiChange: ((String?) -> Void)?

    private var overlayWindows: [EmojiCursorWindow] = []
    private var globalMonitor: Any?
    private var localMonitor: Any?

    private init() {}

    // MARK: - Public API

    func activate(emoji: String) {
        currentEmoji = emoji
        UserDefaults.standard.set(emoji, forKey: "lastEmoji")

        if isActive {
            // Just update the emoji on existing windows
            overlayWindows.forEach { $0.cursorView.emoji = emoji }
            onEmojiChange?(emoji)
            return
        }

        isActive = true
        onEmojiChange?(emoji)
        buildOverlayWindows()
        startTrackingMouse()
        NSCursor.hide()
    }

    func deactivate() {
        guard isActive else { return }
        isActive = false
        onEmojiChange?(nil)

        stopTrackingMouse()
        tearDownOverlayWindows()
        NSCursor.unhide()
        NSCursor.arrow.set()
    }

    // MARK: - Overlay window management

    private func buildOverlayWindows() {
        tearDownOverlayWindows()
        for screen in NSScreen.screens {
            let window = EmojiCursorWindow(screen: screen, emoji: currentEmoji)
            window.orderFrontRegardless()
            overlayWindows.append(window)
        }
        // Rebuild if screens change
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    private func tearDownOverlayWindows() {
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
        NotificationCenter.default.removeObserver(
            self,
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screensChanged() {
        guard isActive else { return }
        buildOverlayWindows()
    }

    // MARK: - Mouse tracking

    private func startTrackingMouse() {
        let mask: NSEvent.EventTypeMask = [
            .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged
        ]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            self?.syncMousePosition()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.syncMousePosition()
            return event
        }
        syncMousePosition()
    }

    private func stopTrackingMouse() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor  { NSEvent.removeMonitor(m); localMonitor  = nil }
    }

    private func syncMousePosition() {
        let pt = NSEvent.mouseLocation
        for window in overlayWindows {
            window.updateMousePosition(pt)
        }
    }
}

// MARK: - EmojiCursorWindow

/// A borderless, transparent, click-through window that paints the emoji
/// cursor over one physical screen.
final class EmojiCursorWindow: NSWindow {
    let cursorView: EmojiCursorView

    init(screen: NSScreen, emoji: String) {
        cursorView = EmojiCursorView(emoji: emoji)

        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )

        isOpaque = false
        backgroundColor = .clear
        // Sit above everything, including full-screen apps
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.overlayWindow)) + 1)
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isReleasedWhenClosed = false
        contentView = cursorView
    }

    func updateMousePosition(_ screenPoint: NSPoint) {
        // Convert from global screen coords to this window's coordinate space
        let localX = screenPoint.x - frame.origin.x
        let localY = screenPoint.y - frame.origin.y
        cursorView.mousePosition = NSPoint(x: localX, y: localY)
        // Only redraw the region near the cursor to keep CPU usage low
        let size = cursorView.cursorSize + 4
        cursorView.setNeedsDisplay(NSRect(
            x: localX - 2, y: localY - size - 2,
            width: size + 4, height: size + 4
        ))
    }
}

// MARK: - EmojiCursorView

/// NSView subclass that renders the emoji at the current mouse position.
final class EmojiCursorView: NSView {
    var emoji: String {
        didSet { cachedImage = nil; needsDisplay = true }
    }
    var mousePosition: NSPoint = .zero
    let cursorSize: CGFloat = 32

    private var cachedImage: NSImage?

    init(emoji: String) {
        self.emoji = emoji
        super.init(frame: .zero)
        wantsLayer = true
        // Transparent backing
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        guard let image = emojiImage() else { return }

        // mousePosition is in view coords (non-flipped: y=0 at bottom).
        // Place the top-left of the emoji image at the mouse hotspot.
        let drawOrigin = NSPoint(
            x: mousePosition.x,
            y: mousePosition.y - cursorSize   // shift down by height so top aligns with mouseY
        )
        image.draw(
            in: NSRect(origin: drawOrigin, size: NSSize(width: cursorSize, height: cursorSize)),
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0
        )
    }

    // MARK: - Emoji → NSImage

    /// Renders the emoji string into a square NSImage once and caches it.
    private func emojiImage() -> NSImage? {
        if let img = cachedImage { return img }

        let size = CGSize(width: cursorSize, height: cursorSize)
        let image = NSImage(size: size)
        image.lockFocus()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: cursorSize * 0.85)
        ]
        let str = NSAttributedString(string: emoji, attributes: attrs)
        let strSize = str.size()
        // Centre the glyph within the square canvas
        let origin = NSPoint(
            x: (size.width  - strSize.width)  / 2,
            y: (size.height - strSize.height) / 2
        )
        str.draw(at: origin)

        image.unlockFocus()
        cachedImage = image
        return image
    }
}
