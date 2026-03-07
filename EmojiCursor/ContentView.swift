import SwiftUI
import AppKit

// MARK: - ContentView

struct ContentView: View {
    @EnvironmentObject private var cursorManager: CursorManager
    @State private var selectedEmoji: String = UserDefaults.standard.string(forKey: "lastEmoji") ?? "😀"
    @State private var searchText: String = ""
    @State private var selectedCategory: String = EmojiData.categories[0].id
    @State private var skinToneEmoji: String? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            header
            if !cursorManager.hasAccessibility {
                accessibilityBanner
            }
            Divider()
            emojiBrowserSection
                .padding(.horizontal, 16)
                .padding(.top, 12)
            Divider()
                .padding(.top, 8)
            settingsSection
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            Divider()
            actionBar
        }
        .frame(width: 300)
    }

    // MARK: - Subviews

    private var accessibilityBanner: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Accessibility (Optional)")
                    .font(.caption).bold()
                Text("Grant for smoother cursor tracking.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Grant") {
                cursorManager.requestAccessibilityPermission()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
    }

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

    // MARK: - Emoji Browser

    private var currentEmojis: [String] {
        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        if query.isEmpty {
            return EmojiData.categories.first(where: { $0.id == selectedCategory })?.emojis ?? []
        }
        return EmojiData.categories.flatMap { $0.emojis }.filter { emoji in
            emoji.unicodeScalars.contains { scalar in
                let name = scalar.properties.name?.lowercased() ?? ""
                return name.contains(query)
            }
        }
    }

    private var emojiBrowserSection: some View {
        VStack(spacing: 6) {
            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 11))
                TextField("Search emojis…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5)))

            // Category tab bar (hidden during search)
            if searchText.isEmpty {
                HStack(spacing: 0) {
                    ForEach(EmojiData.categories) { category in
                        Button {
                            selectedCategory = category.id
                        } label: {
                            Text(category.icon)
                                .font(.system(size: 16))
                                .frame(maxWidth: .infinity)
                                .frame(height: 26)
                                .background(
                                    selectedCategory == category.id
                                    ? Color.accentColor.opacity(0.2)
                                    : Color.clear
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Emoji grid
            let emojis = currentEmojis
            if emojis.isEmpty {
                Text("No emojis found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
            } else {
                ScrollView(.vertical) {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(emojis, id: \.self) { emoji in
                            emojiButton(emoji)
                        }
                    }
                }
                .frame(height: 200)
            }
        }
    }

    // MARK: - Emoji Button with Skin Tone

    private func selectEmoji(_ emoji: String) {
        selectedEmoji = emoji
        cursorManager.activate(emoji: emoji)
    }

    private func emojiButton(_ emoji: String) -> some View {
        let hasSkinTones = EmojiSkinTone.supportsSkinTone(emoji)
        let base = EmojiSkinTone.stripSkinTone(emoji)
        let isSelected = selectedEmoji == emoji ||
            (hasSkinTones && EmojiSkinTone.stripSkinTone(selectedEmoji) == base)

        return Button {
            if hasSkinTones {
                skinToneEmoji = emoji
            } else {
                selectEmoji(emoji)
            }
        } label: {
            Text(emoji)
                .font(.system(size: 24))
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    isSelected
                    ? Color.accentColor.opacity(0.2)
                    : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(
                            isSelected
                            ? Color.accentColor : Color.clear,
                            lineWidth: 1.5
                        )
                )
        }
        .buttonStyle(.plain)
        .popover(isPresented: Binding(
            get: { skinToneEmoji == emoji },
            set: { if !$0 { skinToneEmoji = nil } }
        ), arrowEdge: .bottom) {
            skinTonePopover(for: emoji)
        }
    }

    private func skinTonePopover(for emoji: String) -> some View {
        let variants = EmojiSkinTone.variants(for: emoji)
        return HStack(spacing: 4) {
            ForEach(variants, id: \.self) { variant in
                Button {
                    selectEmoji(variant)
                    skinToneEmoji = nil
                } label: {
                    Text(variant)
                        .font(.system(size: 28))
                        .frame(width: 36, height: 36)
                        .background(
                            selectedEmoji == variant
                            ? Color.accentColor.opacity(0.2)
                            : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
    }

    @State private var settingsExpanded: Bool = false

    private var settingsSection: some View {
        DisclosureGroup(isExpanded: $settingsExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                // Size
                VStack(alignment: .leading, spacing: 4) {
                    Text("Size")
                        .font(.caption2)
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

                Divider()

                // Spring physics
                Toggle("Spring physics", isOn: Binding(
                    get: { cursorManager.springEnabled },
                    set: { cursorManager.setSpringEnabled($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)

                // Alive motion
                Toggle("Alive motion", isOn: Binding(
                    get: { cursorManager.aliveMotion },
                    set: { cursorManager.setAliveMotion($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)

                // Tail
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

                Divider()

                // Launch at login
                Toggle("Launch at login", isOn: Binding(
                    get: { cursorManager.launchAtLogin },
                    set: { cursorManager.setLaunchAtLogin($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
            }
            .padding(.top, 4)
        } label: {
            Text("Settings")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            Text(selectedEmoji)
                .font(.system(size: 28))

            if cursorManager.isActive {
                Button("Reset") {
                    cursorManager.deactivate()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
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
        .padding(.vertical, 8)
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
