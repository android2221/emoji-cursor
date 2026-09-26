import AppKit
import SwiftUI

extension Notification.Name {
    static let popoverDidShow = Notification.Name("popoverDidShow")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private static let hasLaunchedBeforeKey = "hasLaunchedBefore"

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let cursorManager = CursorManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests use the app as their host; don't start the overlay under them.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }

        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            button.image = NSImage(systemSymbolName: "face.smiling",
                                   accessibilityDescription: "Emoji Cursor")?
                .withSymbolConfiguration(config)
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 420)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: ContentView().environmentObject(cursorManager)
        )
        self.popover = popover

        // Auto-activate with last used emoji on launch
        cursorManager.activate(emoji: cursorManager.currentEmoji)

        // Menu-bar apps have no window, so on first launch open the popover to
        // show the user where the app lives.
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: Self.hasLaunchedBeforeKey) {
            defaults.set(true, forKey: Self.hasLaunchedBeforeKey)
            // Wait a runloop turn so the status item has been laid out.
            DispatchQueue.main.async { [weak self] in self?.showPopover() }
        }
    }

    /// Launching the app again (Finder, Spotlight, Launchpad) while it's
    /// running opens the popover — useful when the menu bar icon is hidden
    /// behind the notch or other menu bar items.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPopover()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        cursorManager.deactivate()
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover?.isShown == true {
            popover?.performClose(sender)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let popover, let button = statusItem?.button, !popover.isShown else { return }
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        NotificationCenter.default.post(name: .popoverDidShow, object: nil)
    }
}
