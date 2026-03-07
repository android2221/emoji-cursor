import AppKit
import ApplicationServices
import ServiceManagement

/// Floats an emoji decoration next to the system cursor. The real pointer
/// stays visible — the emoji just rides along as a charm / gem.
/// Hides automatically in lock-step with the system cursor by polling
/// its actual visibility state.
final class CursorManager: ObservableObject {
    static let shared = CursorManager()

    @Published private(set) var isActive = false
    @Published private(set) var currentEmoji = UserDefaults.standard.string(forKey: "lastEmoji") ?? "😀"
    @Published private(set) var hasAccessibility = AXIsProcessTrusted()
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled

    var onStatusChange: ((String?) -> Void)?

    private var overlayWindows: [NSWindow] = []
    private var emojiLayers: [CALayer] = []

    // Event sources
    private var eventTap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var visibilityTimer: DispatchSourceTimer?

    /// Offset from cursor tip so the emoji sits just below-right of the arrow.
    private let offset = CGPoint(x: 5, y: -6)
    @Published var emojiSize: CGFloat = UserDefaults.standard.object(forKey: "emojiSize") as? CGFloat ?? 32

    private var emojiHidden = false

    private init() {}

    // MARK: - Public

    func activate(emoji: String) {
        currentEmoji = emoji
        UserDefaults.standard.set(emoji, forKey: "lastEmoji")

        if isActive {
            updateEmojiImage()
            onStatusChange?(emoji)
            return
        }

        isActive = true
        onStatusChange?(emoji)
        setupOverlays()
        startTracking()
        startVisibilityPolling()
        syncPosition(NSEvent.mouseLocation)
    }

    func deactivate() {
        guard isActive else { return }
        isActive = false
        onStatusChange?(nil)
        stopTracking()
        stopVisibilityPolling()
        tearDownOverlays()
    }

    func requestAccessibilityPermission() {
        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.recheckAccessibility()
        }
    }

    func recheckAccessibility() {
        let trusted = AXIsProcessTrusted()
        guard hasAccessibility != trusted else { return }
        hasAccessibility = trusted
        if isActive { stopTracking(); startTracking() }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    // MARK: - Overlays

    private func setupOverlays() {
        tearDownOverlays()
        let image = makeEmojiImage()
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

            let layer = CALayer()
            layer.bounds = CGRect(origin: .zero, size: CGSize(width: emojiSize, height: emojiSize))
            layer.anchorPoint = CGPoint(x: 0, y: 1)
            layer.contentsGravity = .resizeAspect
            layer.contents = image
            view.layer?.addSublayer(layer)

            window.orderFrontRegardless()
            overlayWindows.append(window)
            emojiLayers.append(layer)
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
    }

    private func tearDownOverlays() {
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
        emojiLayers.removeAll()
        NotificationCenter.default.removeObserver(
            self, name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
    }

    @objc private func screensChanged() {
        guard isActive else { return }
        setupOverlays()
    }

    private func updateEmojiImage() {
        let image = makeEmojiImage()
        let bounds = CGRect(origin: .zero, size: CGSize(width: emojiSize, height: emojiSize))
        for layer in emojiLayers {
            layer.bounds = bounds
            layer.contents = image
        }
    }

    func updateSize(_ size: CGFloat) {
        emojiSize = size
        UserDefaults.standard.set(size, forKey: "emojiSize")
        if isActive { updateEmojiImage() }
    }

    // MARK: - Mouse tracking

    private func startTracking() {
        if hasAccessibility, installEventTap() {}
        else { installNSEventMonitors() }
    }

    private func stopTracking() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let src = tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        }
        eventTap = nil; tapSource = nil

        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor  { NSEvent.removeMonitor(m) }
        globalMonitor = nil; localMonitor = nil

        setEmojiHidden(false)
    }

    private func installEventTap() -> Bool {
        var mask: CGEventMask = 0
        for t: CGEventType in [.mouseMoved, .leftMouseDragged,
                                .rightMouseDragged, .otherMouseDragged] {
            mask |= (1 << t.rawValue)
        }

        let ptr = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .listenOnly, eventsOfInterest: mask,
            callback: { _, _, event, info -> Unmanaged<CGEvent>? in
                guard let info else { return Unmanaged.passRetained(event) }
                let mgr = Unmanaged<CursorManager>.fromOpaque(info).takeUnretainedValue()
                let cg = event.location
                let h = NSScreen.screens.first?.frame.height ?? 0
                mgr.syncPosition(NSPoint(x: cg.x, y: h - cg.y))
                return Unmanaged.passRetained(event)
            }, userInfo: ptr
        ) else { return false }

        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap; tapSource = src
        return true
    }

    private func installNSEventMonitors() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            self?.syncPosition(NSEvent.mouseLocation)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.syncPosition(NSEvent.mouseLocation)
            return event
        }
    }

    // MARK: - Cursor visibility polling

    /// Resolve the actual CGCursorIsVisible function at runtime.
    /// The symbol exists in the CoreGraphics dylib but the macOS 15 SDK
    /// header marks it unavailable, so we load it dynamically.
    /// Falls back to trying _CGSDefaultConnection + CGSCursorIsVisible(conn).
    private static let queryCursorVisible: (() -> Bool)? = {
        let cg = "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics"
        guard let handle = dlopen(cg, RTLD_LAZY) else { return nil }

        // Try 1: CGCursorIsVisible() — public but deprecated/unavailable in SDK
        if let sym = dlsym(handle, "CGCursorIsVisible") {
            let fn = unsafeBitCast(sym, to: (@convention(c) () -> Int32).self)
            return { fn() != 0 }
        }

        // Try 2: _CGSDefaultConnection() + CGSCursorIsVisible(conn)
        if let connSym = dlsym(handle, "_CGSDefaultConnection"),
           let visSym = dlsym(handle, "CGSCursorIsVisible") {
            let connFn = unsafeBitCast(connSym, to: (@convention(c) () -> Int32).self)
            let visFn = unsafeBitCast(visSym, to: (@convention(c) (Int32) -> Int32).self)
            return { visFn(connFn()) != 0 }
        }

        return nil
    }()

    private func startVisibilityPolling() {
        guard let isVisible = Self.queryCursorVisible else { return }

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(50))
        timer.setEventHandler { [weak self] in
            self?.setEmojiHidden(!isVisible())
        }
        timer.resume()
        visibilityTimer = timer
    }

    private func stopVisibilityPolling() {
        visibilityTimer?.cancel()
        visibilityTimer = nil
    }

    private func setEmojiHidden(_ hidden: Bool) {
        guard emojiHidden != hidden else { return }
        emojiHidden = hidden
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        emojiLayers.forEach { $0.opacity = hidden ? 0 : 1 }
        CATransaction.commit()
    }

    // MARK: - Position

    private func syncPosition(_ screen: NSPoint) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for i in overlayWindows.indices {
            let origin = overlayWindows[i].frame.origin
            emojiLayers[i].position = CGPoint(
                x: screen.x - origin.x + offset.x,
                y: screen.y - origin.y + offset.y
            )
        }
        CATransaction.commit()
    }

    // MARK: - Render

    private func makeEmojiImage() -> CGImage? {
        let sz = NSSize(width: emojiSize, height: emojiSize)
        let img = NSImage(size: sz)
        img.lockFocus()
        let str = NSAttributedString(string: currentEmoji, attributes: [
            .font: NSFont.systemFont(ofSize: emojiSize * 0.85)
        ])
        let strSz = str.size()
        str.draw(at: NSPoint(x: (sz.width - strSz.width) / 2,
                             y: (sz.height - strSz.height) / 2))
        img.unlockFocus()
        return img.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
