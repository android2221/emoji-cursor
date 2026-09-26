import SwiftUI
import AppKit

// MARK: - ContentView

struct ContentView: View {
    @EnvironmentObject private var cursorManager: CursorManager
    @State private var searchText: String = ""
    @State private var selectedCategory: String = EmojiData.categories[0].id
    @State private var skinToneEmoji: String? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            emojiBrowserSection
                .padding(.horizontal, 16)
                .padding(.top, 12)
            Divider()
                .padding(.top, 8)
            settingsSection
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            Divider()
            actionBar
        }
        .frame(width: 300)
        .onReceive(NotificationCenter.default.publisher(for: .popoverDidShow)) { _ in
            searchText = ""
            cursorManager.refreshLaunchAtLogin()
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Image(systemName: "face.smiling")
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
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("q")
            .help("Quit EmojiCursor")
            .accessibilityLabel("Quit EmojiCursor")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Emoji Browser

    private var emojiBrowserSection: some View {
        VStack(spacing: 6) {
            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 13))
                TextField("Search emojis…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5)))

            // Category tab bar (hidden during search)
            if searchText.isEmpty {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(EmojiData.categories) { category in
                            Button {
                                selectedCategory = category.id
                            } label: {
                                Text(category.icon)
                                    .font(.system(size: 14))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 24)
                                    .background(
                                        selectedCategory == category.id
                                        ? Color.accentColor.opacity(0.2)
                                        : Color.clear
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                            .buttonStyle(.plain)
                            .help(category.title)
                            .accessibilityLabel(category.title)
                            .accessibilityAddTraits(selectedCategory == category.id ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5)))
                    Divider()
                        .padding(.top, 6)
                }
            }

            // Emoji grid
            let emojis = EmojiData.emojis(category: selectedCategory, query: searchText)
            if emojis.isEmpty {
                Text("No emojis found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
            } else {
                ScrollView(.vertical) {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(Array(emojis.enumerated()), id: \.offset) { _, emoji in
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
        cursorManager.selectEmoji(emoji)
    }

    private func emojiButton(_ emoji: String) -> some View {
        let hasSkinTones = EmojiSkinTone.supportsSkinTone(emoji)
        let base = EmojiSkinTone.stripSkinTone(emoji)
        let isSelected = cursorManager.currentEmoji == emoji ||
            (hasSkinTones && EmojiSkinTone.stripSkinTone(cursorManager.currentEmoji) == base)

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
                            cursorManager.currentEmoji == variant
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

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Settings")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Size")
                    .font(.system(size: 13))
                Slider(value: $cursorManager.emojiSize, in: 16...64, step: 2)
                .controlSize(.regular)
                .padding(.horizontal, 8)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Tail length")
                        .font(.system(size: 13))
                    Spacer()
                    Text(cursorManager.tailLength == 0 ? "Off" : "\(cursorManager.tailLength)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: Binding(
                    get: { Double(cursorManager.tailLength) },
                    set: { cursorManager.tailLength = Int($0) }
                ), in: 0...15, step: 1)
                .controlSize(.regular)
                .padding(.horizontal, 8)
            }

            Toggle(isOn: $cursorManager.springEnabled) {
                Text("Spring physics")
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            Toggle(isOn: $cursorManager.aliveMotion) {
                Text("Alive motion")
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            Toggle(isOn: $cursorManager.jiggleOnClick) {
                Text("Jiggle on click")
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            Toggle(isOn: Binding(
                get: { cursorManager.launchAtLogin },
                set: { cursorManager.setLaunchAtLogin($0) }
            )) {
                Text("Launch at login")
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            Text(cursorManager.currentEmoji)
                .font(.system(size: 28))

            Spacer()

            if cursorManager.isActive {
                Button("Clear Emoji") {
                    cursorManager.deactivate()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .keyboardShortcut(.return, modifiers: [])
            } else {
                Button("Activate Emoji") {
                    cursorManager.activate(emoji: cursorManager.currentEmoji)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
