import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let cursorManager = CursorManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "cursorarrow.rays",
                                   accessibilityDescription: "Emoji Cursor")
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
        if let lastEmoji = UserDefaults.standard.string(forKey: "lastEmoji") {
            cursorManager.activate(emoji: lastEmoji)
        }

        cursorManager.onStatusChange = { [weak self] emoji in
            DispatchQueue.main.async {
                guard let button = self?.statusItem?.button else { return }
                if let emoji {
                    button.title = emoji
                    button.image = nil
                } else {
                    button.title = ""
                    button.image = NSImage(systemSymbolName: "cursorarrow.rays",
                                           accessibilityDescription: "Emoji Cursor")
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        cursorManager.deactivate()
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
