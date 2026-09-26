import AppKit
import ServiceManagement

/// Floats an emoji charm next to the system cursor with springy physics.
/// Hides in lock-step with the system cursor by polling CGCursorIsVisible.
final class CursorManager: ObservableObject {
    static let shared = CursorManager()

    enum DefaultsKey {
        static let lastEmoji = "lastEmoji"
        static let emojiSize = "emojiSize"
        static let springEnabled = "springEnabled"
        static let tailLength = "tailLength"
        static let aliveMotion = "aliveMotion"
        static let jiggleOnClick = "jiggleOnClick"
    }

    @Published private(set) var isActive = false
    @Published var currentEmoji: String
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published var emojiSize: CGFloat
    @Published var springEnabled: Bool {
        didSet { defaults.set(springEnabled, forKey: DefaultsKey.springEnabled) }
    }
    @Published var tailLength: Int
    @Published var aliveMotion: Bool
    @Published var jiggleOnClick: Bool {
        didSet { defaults.set(jiggleOnClick, forKey: DefaultsKey.jiggleOnClick) }
    }

    private let defaults: UserDefaults
    private let overlay = EmojiOverlay()

    // Event sources
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var clickMonitor: Any?
    private var localClickMonitor: Any?
    private var visibilityTimer: DispatchSourceTimer?
    private var displayLink: CADisplayLink?
    private var lastFrameTime: CFTimeInterval = 0

    private var spring = SpringPhysics()
    private var animation = AnimationState()
    private var tail = TailTrail()
    private var emojiHidden = false

    /// Offset from cursor tip — tuck it right against the arrow.
    private let offset = CGPoint(x: 3, y: -4)

    init(defaults: UserDefaults = .standard,
         reduceMotion: Bool = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion) {
        self.defaults = defaults
        // Register before reading so first-run values come from here.
        defaults.register(defaults: [
            DefaultsKey.lastEmoji: "😀",
            DefaultsKey.emojiSize: 28.0,
            DefaultsKey.springEnabled: !reduceMotion,
            DefaultsKey.jiggleOnClick: !reduceMotion,
            DefaultsKey.tailLength: 0,
            DefaultsKey.aliveMotion: false,
        ])
        currentEmoji = defaults.string(forKey: DefaultsKey.lastEmoji) ?? "😀"
        emojiSize = CGFloat(defaults.double(forKey: DefaultsKey.emojiSize))
        springEnabled = defaults.bool(forKey: DefaultsKey.springEnabled)
        tailLength = defaults.integer(forKey: DefaultsKey.tailLength)
        aliveMotion = defaults.bool(forKey: DefaultsKey.aliveMotion)
        jiggleOnClick = defaults.bool(forKey: DefaultsKey.jiggleOnClick)
    }

    // MARK: - Public

    func selectEmoji(_ emoji: String) {
        currentEmoji = emoji
        defaults.set(emoji, forKey: DefaultsKey.lastEmoji)
        if isActive {
            overlay.setEmoji(emoji, size: emojiSize)
        }
    }

    func activate(emoji: String) {
        selectEmoji(emoji)
        guard !isActive else { return }

        isActive = true
        overlay.build(emoji: currentEmoji, size: emojiSize)
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        startTracking()
        startVisibilityPolling()
        startDisplayLink()

        // Snap to initial position (no spring lag on first show)
        let pos = NSEvent.mouseLocation
        spring.snap(to: CGPoint(x: pos.x + offset.x, y: pos.y + offset.y))
        render()
    }

    func deactivate() {
        guard isActive else { return }
        isActive = false
        stopTracking()
        stopVisibilityPolling()
        stopDisplayLink()
        NotificationCenter.default.removeObserver(
            self, name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        overlay.tearDown()
        tail.clear()
        emojiHidden = false
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refreshLaunchAtLogin()
            // macOS may want the user to allow the login item first.
            if enabled && SMAppService.mainApp.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
        } catch {
            refreshLaunchAtLogin()
        }
    }

    /// The user can remove the login item in System Settings; re-read it.
    func refreshLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func updateSize(_ size: CGFloat) {
        emojiSize = size
        defaults.set(Double(size), forKey: DefaultsKey.emojiSize)
        if isActive {
            overlay.setEmoji(currentEmoji, size: size)
        }
    }

    func setAliveMotion(_ enabled: Bool) {
        aliveMotion = enabled
        defaults.set(enabled, forKey: DefaultsKey.aliveMotion)
        wake()
    }

    func setTailLength(_ length: Int) {
        tailLength = length
        defaults.set(length, forKey: DefaultsKey.tailLength)
        if length == 0 { tail.clear() }
        wake()
    }

    // MARK: - Screens

    @objc private func screensChanged() {
        guard isActive else { return }
        stopDisplayLink()
        overlay.build(emoji: currentEmoji, size: emojiSize)
        overlay.setHidden(emojiHidden)
        startDisplayLink()
    }

    // MARK: - Mouse tracking

    private func startTracking() {
        let moveMask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: moveMask) { [weak self] _ in
            self?.setTarget(NSEvent.mouseLocation)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: moveMask) { [weak self] event in
            self?.setTarget(NSEvent.mouseLocation)
            return event
        }

        // Global monitors never see our own events, so clicks inside the
        // popover need a local monitor too.
        let clickMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown]
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: clickMask) { [weak self] _ in
            self?.triggerJiggle()
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: clickMask) { [weak self] event in
            self?.triggerJiggle()
            return event
        }
    }

    private func stopTracking() {
        for monitor in [globalMonitor, localMonitor, clickMonitor, localClickMonitor].compactMap({ $0 }) {
            NSEvent.removeMonitor(monitor)
        }
        globalMonitor = nil; localMonitor = nil; clickMonitor = nil; localClickMonitor = nil
    }

    private func triggerJiggle() {
        guard jiggleOnClick else { return }
        animation.triggerJiggle()
        wake()
    }

    /// Called on every mouse event — just updates the target, the display
    /// link handles the smooth interpolation.
    private func setTarget(_ mouse: NSPoint) {
        spring.target = CGPoint(x: mouse.x + offset.x, y: mouse.y + offset.y)
        wake()
    }

    // MARK: - Frame loop

    /// The display link runs only while something is moving, and pauses
    /// itself when everything has come to rest so an idle cursor costs nothing.
    private func startDisplayLink() {
        guard displayLink == nil, let window = overlay.primaryWindow else { return }
        let link = window.displayLink(target: self, selector: #selector(displayLinkFired(_:)))
        link.add(to: .main, forMode: .common)
        lastFrameTime = 0
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    /// Resume per-frame updates after input or a settings change.
    private func wake() {
        guard let link = displayLink, link.isPaused else { return }
        lastFrameTime = 0
        link.isPaused = false
    }

    @objc private func displayLinkFired(_ link: CADisplayLink) {
        let now = link.timestamp
        let dt = lastFrameTime > 0 ? min(now - lastFrameTime, 1.0 / 30.0) : 1.0 / 60.0
        lastFrameTime = now
        step(dt: dt)
        if isIdle { link.isPaused = true }
    }

    private var isIdle: Bool {
        emojiHidden || (spring.isSettled && !aliveMotion && !animation.isJiggling
                        && tail.isSettled(at: spring.current))
    }

    /// Advance the simulation one frame and redraw.
    private func step(dt: Double) {
        guard isActive, !emojiHidden else { return }

        if springEnabled {
            spring.step(dt: CGFloat(dt))
        } else {
            spring.snap(to: spring.target)
        }
        animation.tick(dt: dt, aliveEnabled: aliveMotion)
        tail.record(spring.current, length: tailLength)
        render()
    }

    private func render() {
        overlay.update(position: spring.current, animation: animation, aliveEnabled: aliveMotion,
                       tail: tail, tailLength: tailLength)
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
        timer.schedule(deadline: .now(), repeating: .milliseconds(50), leeway: .milliseconds(10))
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
        overlay.setHidden(hidden)
        if hidden {
            tail.clear()
        } else {
            wake()
        }
    }
}
