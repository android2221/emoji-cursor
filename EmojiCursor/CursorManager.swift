import AppKit
import ApplicationServices

// MARK: - CursorManager

/// Manages the emoji cursor overlay. Replaces the system cursor by:
///   1. Hiding the real cursor with NSCursor.hide()
///   2. Showing a transparent full-screen overlay window per screen
///
/// Two event-delivery strategies are used, best-first:
///   • CGEvent tap  — intercepts mouse events very early in the pipeline
///     (before WindowServer dispatch), giving near-zero latency. Requires
///     Accessibility permission.
///   • NSEvent global monitor — fallback when Accessibility is not granted.
///
/// Rendering uses a CALayer whose `position` is updated directly; this lets
/// Core Animation's compositor move the emoji without any CPU redraw.
final class CursorManager: ObservableObject {
    static let shared = CursorManager()

    @Published private(set) var isActive = false
    @Published private(set) var currentEmoji: String = UserDefaults.standard.string(forKey: "lastEmoji") ?? "😀"
    @Published private(set) var hasAccessibility = AXIsProcessTrusted()

    /// Called whenever the active emoji / active-state changes (syncs the status bar icon).
    var onEmojiChange: ((String?) -> Void)?

    private var overlayWindows: [EmojiCursorWindow] = []

    // CGEvent tap (low-latency path)
    private var eventTap: CFMachPort?
    private var tapRunLoopSource: CFRunLoopSource?

    // NSEvent monitors (fallback path)
    private var globalMonitor: Any?
    private var localMonitor: Any?

    private init() {}

    // MARK: - Public API

    func activate(emoji: String) {
        currentEmoji = emoji
        UserDefaults.standard.set(emoji, forKey: "lastEmoji")

        if isActive {
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

    /// Shows the system Accessibility prompt and re-checks the result.
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        // Poll briefly — the user may grant in the Settings window that just opened.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.recheckAccessibility()
        }
    }

    func recheckAccessibility() {
        let trusted = AXIsProcessTrusted()
        if hasAccessibility != trusted {
            hasAccessibility = trusted
            // Restart tracking with the better (or worse) strategy
            if isActive {
                stopTrackingMouse()
                startTrackingMouse()
            }
        }
    }

    // MARK: - Overlay windows

    private func buildOverlayWindows() {
        tearDownOverlayWindows()
        for screen in NSScreen.screens {
            let w = EmojiCursorWindow(screen: screen, emoji: currentEmoji)
            w.orderFrontRegardless()
            overlayWindows.append(w)
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
    }

    private func tearDownOverlayWindows() {
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
        NotificationCenter.default.removeObserver(
            self, name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
    }

    @objc private func screensChanged() {
        guard isActive else { return }
        buildOverlayWindows()
    }

    // MARK: - Mouse tracking

    private func startTrackingMouse() {
        if hasAccessibility, startCGEventTap() {
            // High-performance path active
        } else {
            startNSEventMonitors()
        }
        syncMousePosition(NSEvent.mouseLocation)
    }

    private func stopTrackingMouse() {
        stopCGEventTap()
        stopNSEventMonitors()
    }

    // MARK: CGEvent tap (low-latency)

    /// Returns true if the tap was successfully installed.
    @discardableResult
    private func startCGEventTap() -> Bool {
        let mask: CGEventMask =
            (1 << CGEventType.mouseMoved.rawValue)         |
            (1 << CGEventType.leftMouseDragged.rawValue)   |
            (1 << CGEventType.rightMouseDragged.rawValue)  |
            (1 << CGEventType.otherMouseDragged.rawValue)

        // Use an unretained pointer to self as callback context.
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<CursorManager>.fromOpaque(userInfo).takeUnretainedValue()
                // Convert CGEvent coords (y=0 at top of primary screen) to
                // NSEvent-style screen coords (y=0 at bottom of primary screen).
                let cg = event.location
                let screenH = NSScreen.screens.first?.frame.height ?? 0
                let nsPoint = NSPoint(x: cg.x, y: screenH - cg.y)
                manager.syncMousePosition(nsPoint)
                return Unmanaged.passRetained(event)
            },
            userInfo: selfPtr
        ) else { return false }

        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        tapRunLoopSource = src
        return true
    }

    private func stopCGEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let src = tapRunLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
            }
        }
        eventTap = nil
        tapRunLoopSource = nil
    }

    // MARK: NSEvent monitors (fallback)

    private func startNSEventMonitors() {
        let mask: NSEvent.EventTypeMask = [
            .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged
        ]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            self?.syncMousePosition(NSEvent.mouseLocation)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.syncMousePosition(NSEvent.mouseLocation)
            return event
        }
    }

    private func stopNSEventMonitors() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor  { NSEvent.removeMonitor(m); localMonitor  = nil }
    }

    // MARK: Position dispatch

    func syncMousePosition(_ pt: NSPoint) {
        // Called from the CGEvent tap callback on the main run loop —
        // or from NSEvent monitors which are already on the main thread.
        for window in overlayWindows {
            window.updateMousePosition(pt)
        }
    }
}

// MARK: - EmojiCursorWindow

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
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.overlayWindow)) + 1)
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isReleasedWhenClosed = false
        contentView = cursorView
    }

    func updateMousePosition(_ screenPoint: NSPoint) {
        // Convert global screen coords → this window's local coordinate space.
        let localX = screenPoint.x - frame.origin.x
        let localY = screenPoint.y - frame.origin.y
        cursorView.updatePosition(NSPoint(x: localX, y: localY))
    }
}

// MARK: - EmojiCursorView

/// Hosts a single CALayer that displays the emoji image. Moving the cursor
/// is a CALayer position update — no CPU redraw, handled entirely by the
/// Core Animation compositor.
final class EmojiCursorView: NSView {
    let cursorSize: CGFloat = 32

    var emoji: String {
        didSet {
            guard emoji != oldValue else { return }
            emojiLayer.contents = makeEmojiImage()
        }
    }

    private let emojiLayer = CALayer()

    init(emoji: String) {
        self.emoji = emoji
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        setupEmojiLayer()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setupEmojiLayer() {
        emojiLayer.bounds = CGRect(x: 0, y: 0, width: cursorSize, height: cursorSize)
        // anchorPoint (0, 1) = top-left corner in CA coords (y=1 is the top
        // of the layer in a non-flipped view where y increases upward).
        emojiLayer.anchorPoint = CGPoint(x: 0, y: 1)
        emojiLayer.contentsGravity = .resizeAspect
        emojiLayer.contents = makeEmojiImage()
        layer?.addSublayer(emojiLayer)
    }

    func updatePosition(_ viewPoint: NSPoint) {
        // Disable implicit animation so the layer snaps instantly to the
        // new position rather than interpolating from the previous one.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // With anchorPoint (0,1), `position` is the top-left corner.
        // viewPoint.y is the mouse Y in non-flipped coords (y=0 at bottom),
        // and we want the TOP of the emoji at that Y, so position.y = viewPoint.y.
        emojiLayer.position = CGPoint(x: viewPoint.x, y: viewPoint.y)
        CATransaction.commit()
    }

    // MARK: - Emoji → CGImage

    private func makeEmojiImage() -> CGImage? {
        let sz = CGSize(width: cursorSize, height: cursorSize)
        let image = NSImage(size: sz)
        image.lockFocus()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: cursorSize * 0.85)
        ]
        let str = NSAttributedString(string: emoji, attributes: attrs)
        let strSize = str.size()
        str.draw(at: NSPoint(
            x: (sz.width  - strSize.width)  / 2,
            y: (sz.height - strSize.height) / 2
        ))
        image.unlockFocus()
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
