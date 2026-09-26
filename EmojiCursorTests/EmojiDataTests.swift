import XCTest
@testable import EmojiCursor

final class EmojiDataTests: XCTestCase {
    func testCategoriesAreNonEmptyWithUniqueIDs() {
        XCTAssertFalse(EmojiData.categories.isEmpty)
        let ids = EmojiData.categories.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        for category in EmojiData.categories {
            XCTAssertFalse(category.emojis.isEmpty, "\(category.id) has no emojis")
        }
    }

    func testKeywordMatchIsSubstring() {
        XCTAssertTrue(EmojiKeywords.matches("🌸", query: "flow"))
        XCTAssertTrue(EmojiKeywords.matches("🐶", query: "puppy"))
        XCTAssertFalse(EmojiKeywords.matches("🐶", query: "cat"))
        XCTAssertFalse(EmojiKeywords.matches("not-an-emoji", query: "flower"))
    }
}

final class EmojiSkinToneTests: XCTestCase {
    func testSupportsSkinTone() {
        XCTAssertTrue(EmojiSkinTone.supportsSkinTone("👍"))
        XCTAssertTrue(EmojiSkinTone.supportsSkinTone("👍🏽"))
        XCTAssertFalse(EmojiSkinTone.supportsSkinTone("😀"))
        XCTAssertFalse(EmojiSkinTone.supportsSkinTone("🌸"))
    }

    func testStripSkinTone() {
        XCTAssertEqual(EmojiSkinTone.stripSkinTone("👍🏿"), "👍")
        XCTAssertEqual(EmojiSkinTone.stripSkinTone("👍"), "👍")
        XCTAssertEqual(EmojiSkinTone.stripSkinTone("😀"), "😀")
    }

    func testVariantsIncludeBaseThenFiveTones() {
        XCTAssertEqual(EmojiSkinTone.variants(for: "👋🏼"), ["👋", "👋🏻", "👋🏼", "👋🏽", "👋🏾", "👋🏿"])
    }

    func testVariantsForUnsupportedEmojiIsJustTheEmoji() {
        XCTAssertEqual(EmojiSkinTone.variants(for: "🌸"), ["🌸"])
    }

    func testToneIsInsertedAfterModifierBaseInZWJSequence() {
        // 🧑‍💻 (person + ZWJ + laptop): tone goes right after the person scalar.
        let variants = EmojiSkinTone.variants(for: "🧑‍💻")
        XCTAssertEqual(variants.count, 6)
        XCTAssertEqual(variants[1], "🧑🏻‍💻")
    }
}
