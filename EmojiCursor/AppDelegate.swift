import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let cursorManager = CursorManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock — lives only in the menu bar
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
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: ContentView().environmentObject(cursorManager)
        )
        self.popover = popover

        // Keep status bar icon in sync with active emoji
        cursorManager.onEmojiChange = { [weak self] emoji in
            DispatchQueue.main.async { self?.updateStatusIcon(emoji: emoji) }
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
            // Temporarily show the real cursor while the popover is open
            if cursorManager.isActive {
                NSCursor.unhide()
            }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - NSPopoverDelegate

    func popoverWillClose(_ notification: Notification) {
        // Re-hide the cursor when the settings popover closes
        if cursorManager.isActive {
            NSCursor.hide()
        }
    }

    // MARK: - Helpers

    private func updateStatusIcon(emoji: String?) {
        guard let button = statusItem?.button else { return }
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
