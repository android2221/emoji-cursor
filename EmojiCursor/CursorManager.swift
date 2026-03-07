import AppKit
import ApplicationServices
import ServiceManagement

/// Floats an emoji charm next to the system cursor with springy physics.
/// Hides in lock-step with the system cursor by polling CGCursorIsVisible.
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
    private var displayLink: CVDisplayLink?

    /// Where the emoji wants to be (cursor pos + offset), in screen coords.
    private var targetPosition: CGPoint = .zero
    /// Where the emoji actually is right now (lags behind via spring).
    private var currentPosition: CGPoint = .zero
    /// Velocity for the spring simulation.
    private var velocity: CGPoint = .zero

    // Spring parameters
    private let springStiffness: CGFloat = 0.35
    private let springDamping: CGFloat = 0.75

    /// Offset from cursor tip — tuck it right against the arrow.
    private let offset = CGPoint(x: 3, y: -4)

    @Published var emojiSize: CGFloat = UserDefaults.standard.object(forKey: "emojiSize") as? CGFloat ?? 28
    @Published var springEnabled: Bool = UserDefaults.standard.object(forKey: "springEnabled") as? Bool ?? true
    @Published var tailLength: Int = UserDefaults.standard.object(forKey: "tailLength") as? Int ?? 0
    @Published var aliveMotion: Bool = UserDefaults.standard.object(forKey: "aliveMotion") as? Bool ?? false

    private var emojiHidden = false
    private var aliveTime: Double = 0

    // Tail effect
    private var tailLayers: [[CALayer]] = []  // [screenIndex][tailIndex]
    private var positionHistory: [CGPoint] = []
    private let maxTailSlots = 20
    private let tailSpacing = 4  // sample every Nth frame for spacing

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
        startDisplayLink()

        // Snap to initial position (no spring lag on first show)
        let pos = NSEvent.mouseLocation
        targetPosition = CGPoint(x: pos.x + offset.x, y: pos.y + offset.y)
        currentPosition = targetPosition
        velocity = .zero
        updateLayerPositions()
    }

    func deactivate() {
        guard isActive else { return }
        isActive = false
        onStatusChange?(nil)
        stopTracking()
        stopVisibilityPolling()
        stopDisplayLink()
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

            // Subtle drop shadow for depth
            layer.shadowColor = NSColor.black.cgColor
            layer.shadowOpacity = 0.3
            layer.shadowOffset = CGSize(width: 0.5, height: -1)
            layer.shadowRadius = 2

            // Create tail layers (behind the main emoji)
            var screenTailLayers: [CALayer] = []
            for t in 0..<maxTailSlots {
                let tailLayer = CALayer()
                tailLayer.bounds = CGRect(origin: .zero, size: CGSize(width: emojiSize, height: emojiSize))
                tailLayer.anchorPoint = CGPoint(x: 0, y: 1)
                tailLayer.contentsGravity = .resizeAspect
                tailLayer.contents = image
                tailLayer.opacity = 0  // hidden until tail is enabled
                let frac = Float(t + 1) / Float(maxTailSlots)
                tailLayer.transform = CATransform3DMakeScale(CGFloat(1.0 - 0.4 * frac), CGFloat(1.0 - 0.4 * frac), 1)
                view.layer?.addSublayer(tailLayer)
                screenTailLayers.append(tailLayer)
            }

            view.layer?.addSublayer(layer)

            window.orderFrontRegardless()
            overlayWindows.append(window)
            emojiLayers.append(layer)
            tailLayers.append(screenTailLayers)
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
        tailLayers.removeAll()
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
        for screenLayers in tailLayers {
            for (t, layer) in screenLayers.enumerated() {
                layer.bounds = bounds
                layer.contents = image
                let frac = Float(t + 1) / Float(maxTailSlots)
                layer.transform = CATransform3DMakeScale(CGFloat(1.0 - 0.4 * frac), CGFloat(1.0 - 0.4 * frac), 1)
            }
        }
    }

    func updateSize(_ size: CGFloat) {
        emojiSize = size
        UserDefaults.standard.set(size, forKey: "emojiSize")
        if isActive { updateEmojiImage() }
    }

    func setSpringEnabled(_ enabled: Bool) {
        springEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "springEnabled")
    }

    func setAliveMotion(_ enabled: Bool) {
        aliveMotion = enabled
        UserDefaults.standard.set(enabled, forKey: "aliveMotion")
        if !enabled {
            // Reset transforms to identity
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            for layer in emojiLayers {
                layer.transform = CATransform3DIdentity
            }
            CATransaction.commit()
        }
    }

    func setTailLength(_ length: Int) {
        tailLength = length
        UserDefaults.standard.set(length, forKey: "tailLength")
        if length == 0 {
            positionHistory.removeAll()
            // Hide all tail layers
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            for screenLayers in tailLayers {
                for layer in screenLayers { layer.opacity = 0 }
            }
            CATransaction.commit()
        }
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
                mgr.setTarget(NSPoint(x: cg.x, y: h - cg.y))
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
            self?.setTarget(NSEvent.mouseLocation)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.setTarget(NSEvent.mouseLocation)
            return event
        }
    }

    /// Called on every mouse event — just updates the target, the display
    /// link handles the smooth interpolation.
    private func setTarget(_ mouse: NSPoint) {
        targetPosition = CGPoint(x: mouse.x + offset.x, y: mouse.y + offset.y)
    }

    // MARK: - Display link (spring physics)

    private func startDisplayLink() {
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let link else { return }

        let ptr = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(link, { _, _, _, _, _, userInfo -> CVReturn in
            guard let userInfo else { return kCVReturnSuccess }
            let mgr = Unmanaged<CursorManager>.fromOpaque(userInfo).takeUnretainedValue()
            DispatchQueue.main.async { mgr.stepSpring() }
            return kCVReturnSuccess
        }, ptr)

        CVDisplayLinkStart(link)
        displayLink = link
    }

    private func stopDisplayLink() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
        }
        displayLink = nil
    }

    /// Advance the spring simulation one tick and update layers.
    private func stepSpring() {
        guard isActive, !emojiHidden else { return }

        if springEnabled {
            // Spring force: pull currentPosition toward targetPosition
            let dx = targetPosition.x - currentPosition.x
            let dy = targetPosition.y - currentPosition.y

            // If close enough and barely moving, snap to avoid endless micro-updates
            let dist = sqrt(dx * dx + dy * dy)
            let speed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
            if dist < 0.3 && speed < 0.3 {
                if currentPosition.x != targetPosition.x || currentPosition.y != targetPosition.y {
                    currentPosition = targetPosition
                    velocity = .zero
                }
            } else {
                velocity.x += dx * springStiffness
                velocity.y += dy * springStiffness
                velocity.x *= springDamping
                velocity.y *= springDamping
                currentPosition.x += velocity.x
                currentPosition.y += velocity.y
            }
        } else {
            currentPosition = targetPosition
            velocity = .zero
        }

        // Advance alive animation timer (~60fps → 1/60s per tick)
        if aliveMotion {
            aliveTime += 1.0 / 60.0
        }

        // Record position history for tail
        if tailLength > 0 {
            positionHistory.insert(currentPosition, at: 0)
            let needed = tailLength * tailSpacing + 1
            if positionHistory.count > needed {
                positionHistory.removeSubrange(needed...)
            }
        }

        updateLayerPositions()
    }

    private func updateLayerPositions() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for i in overlayWindows.indices {
            let origin = overlayWindows[i].frame.origin
            emojiLayers[i].position = CGPoint(
                x: currentPosition.x - origin.x,
                y: currentPosition.y - origin.y
            )

            // Alive motion: gentle bob + breathe
            if aliveMotion {
                let bobY = CGFloat(sin(aliveTime * 2.5)) * 2.0       // slow vertical bob
                let breathe = 1.0 + CGFloat(sin(aliveTime * 3.0)) * 0.04  // subtle scale pulse
                let tilt = CGFloat(sin(aliveTime * 1.8)) * 0.06      // very gentle sway
                var t = CATransform3DIdentity
                t = CATransform3DTranslate(t, 0, bobY, 0)
                t = CATransform3DScale(t, breathe, breathe, 1)
                t = CATransform3DRotate(t, tilt, 0, 0, 1)
                emojiLayers[i].transform = t
            }

            // Update tail layers
            guard i < tailLayers.count else { continue }
            for t in 0..<maxTailSlots {
                let layer = tailLayers[i][t]
                if t < tailLength {
                    let histIdx = (t + 1) * tailSpacing
                    if histIdx < positionHistory.count {
                        let pos = positionHistory[histIdx]
                        layer.position = CGPoint(x: pos.x - origin.x, y: pos.y - origin.y)
                        layer.opacity = Float(tailLength - t) / Float(tailLength + 1) * 0.6
                    } else {
                        layer.opacity = 0
                    }
                } else {
                    layer.opacity = 0
                }
            }
        }
        CATransaction.commit()
    }

    // MARK: - Cursor visibility polling

    private static let queryCursorVisible: (() -> Bool)? = {
        let cg = "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics"
        guard let handle = dlopen(cg, RTLD_LAZY) else { return nil }

        if let sym = dlsym(handle, "CGCursorIsVisible") {
            let fn = unsafeBitCast(sym, to: (@convention(c) () -> Int32).self)
            return { fn() != 0 }
        }

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
        if hidden {
            for screenLayers in tailLayers {
                for layer in screenLayers { layer.opacity = 0 }
            }
            positionHistory.removeAll()
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
