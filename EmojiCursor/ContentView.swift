import SwiftUI
import AppKit

// MARK: - ContentView

struct ContentView: View {
    @EnvironmentObject private var cursorManager: CursorManager
    @State private var selectedEmoji: String = UserDefaults.standard.string(forKey: "lastEmoji") ?? "😀"
    @State private var customEmojiInput: String = ""
    @FocusState private var emojiFieldFocused: Bool

    private let quickPicks: [[String]] = [
        ["😀", "😂", "😍", "🥳", "😎", "🤩"],
        ["❤️", "🔥", "⭐", "✨", "🎉", "💎"],
        ["🚀", "🌈", "🦄", "🐱", "🍕", "👾"],
        ["👋", "👆", "✌️", "🤙", "👌", "🫵"],
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 16) {
                    previewSection
                    sizeSection
                    effectsSection
                    quickPickSection
                    customPickSection
                    settingsSection
                }
                .padding(16)
            }
            Divider()
            actionBar
        }
        .frame(width: 300)
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Image(systemName: "cursorarrow.rays")
                .foregroundStyle(.secondary)
            Text("Emoji Cursor")
                .font(.headline)
            Spacer()
            if cursorManager.isActive {
                Label("Active", systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .labelStyle(.titleAndIcon)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var previewSection: some View {
        VStack(spacing: 8) {
            Text("Selected Emoji")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.background.secondary)
                    .frame(height: 80)
                Text(selectedEmoji)
                    .font(.system(size: 48))
            }
        }
    }

    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Size")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text("🔹")
                    .font(.system(size: 10))
                Slider(value: Binding(
                    get: { cursorManager.emojiSize },
                    set: { cursorManager.updateSize($0) }
                ), in: 16...64, step: 2)
                Text("🔷")
                    .font(.system(size: 18))
            }
        }
    }

    private var effectsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Effects")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Spring physics", isOn: Binding(
                get: { cursorManager.springEnabled },
                set: { cursorManager.setSpringEnabled($0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Tail length")
                        .font(.caption2)
                    Spacer()
                    Text(cursorManager.tailLength == 0 ? "Off" : "\(cursorManager.tailLength)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Slider(value: Binding(
                    get: { Double(cursorManager.tailLength) },
                    set: { cursorManager.setTailLength(Int($0)) }
                ), in: 0...15, step: 1)
            }
        }
    }

    private var quickPickSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Pick")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                ForEach(quickPicks.indices, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(quickPicks[row], id: \.self) { emoji in
                            Button {
                                selectedEmoji = emoji
                                customEmojiInput = ""
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 22))
                                    .frame(width: 40, height: 36)
                                    .background(
                                        selectedEmoji == emoji
                                        ? Color.accentColor.opacity(0.25)
                                        : Color.clear
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(
                                                selectedEmoji == emoji
                                                ? Color.accentColor : Color.clear,
                                                lineWidth: 1.5
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var customPickSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom Emoji")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                // Text field — tap here then press ⌃⌘Space for the system picker
                EmojiTextField(text: $customEmojiInput, onCommit: applyCustomEmoji)
                    .frame(height: 32)
                    .focused($emojiFieldFocused)

                Button("Pick…") {
                    emojiFieldFocused = true
                    // Open the system emoji & symbol picker
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        NSApp.orderFrontCharacterPalette(nil)
                    }
                }
                .buttonStyle(.bordered)
            }

            Text("Tip: focus the field and press ⌃⌘Space for the emoji picker")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onChange(of: customEmojiInput) {
            if let first = customEmojiInput.first, first.isEmoji {
                selectedEmoji = String(first)
            }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Launch at login", isOn: Binding(
                get: { cursorManager.launchAtLogin },
                set: { cursorManager.setLaunchAtLogin($0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)

            if !cursorManager.hasAccessibility {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility Required")
                            .font(.caption).bold()
                        Text("Needed to hide the emoji while typing and for smoother tracking in all apps.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button("Grant") {
                        cursorManager.requestAccessibilityPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            if cursorManager.isActive {
                Button("Reset to Default") {
                    cursorManager.deactivate()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }

            Spacer()

            Button(cursorManager.isActive ? "Update" : "Set Cursor") {
                cursorManager.activate(emoji: selectedEmoji)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private func applyCustomEmoji() {
        guard let first = customEmojiInput.first, first.isEmoji else { return }
        selectedEmoji = String(first)
    }
}

// MARK: - EmojiTextField (NSViewRepresentable)

/// A thin AppKit wrapper so the system emoji popover (⌃⌘Space) can be invoked.
struct EmojiTextField: NSViewRepresentable {
    @Binding var text: String
    var onCommit: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.delegate = context.coordinator
        field.placeholderString = "Paste or type emoji…"
        field.alignment = .center
        field.font = .systemFont(ofSize: 20)
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.focusRingType = .default
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: EmojiTextField

        init(_ parent: EmojiTextField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            let raw = field.stringValue
            // Keep only the first emoji character
            if let _ = raw.unicodeScalars.first,
               raw.first?.isEmoji == true {
                let emoji = String(raw.prefix(raw.first!.utf16.count))
                parent.text = emoji
                if field.stringValue != emoji {
                    field.stringValue = emoji
                }
            } else {
                parent.text = raw
            }
        }

        func control(_ control: NSControl, textView: NSTextView,
                     doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.insertNewline(_:)) {
                parent.onCommit()
                return true
            }
            return false
        }
    }
}

// MARK: - Character.isEmoji helper

private extension Character {
    var isEmoji: Bool {
        unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x1F600...0x1F64F, // Emoticons
                 0x1F300...0x1F5FF, // Misc Symbols & Pictographs
                 0x1F680...0x1F6FF, // Transport & Map
                 0x1F700...0x1F77F, // Alchemical
                 0x1F780...0x1F7FF, // Geometric Shapes Extended
                 0x1F800...0x1F8FF, // Supplemental Arrows-C
                 0x1F900...0x1F9FF, // Supplemental Symbols & Pictographs
                 0x1FA00...0x1FA6F, // Chess Symbols
                 0x1FA70...0x1FAFF, // Symbols and Pictographs Extended-A
                 0x2600...0x26FF,   // Misc symbols
                 0x2700...0x27BF,   // Dingbats
                 0xFE00...0xFE0F,   // Variation Selectors
                 0x1F1E0...0x1F1FF: // Flags
                return true
            default:
                return false
            }
        }
    }
}
