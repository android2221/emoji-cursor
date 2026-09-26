import XCTest
@testable import EmojiCursor

final class EmojiSearchTests: XCTestCase {
    func testEmptyQueryReturnsTheCategory() {
        let animals = EmojiData.categories.first { $0.id == "animals" }!
        XCTAssertEqual(EmojiData.emojis(category: "animals", query: ""), animals.emojis)
        XCTAssertEqual(EmojiData.emojis(category: "animals", query: "   "), animals.emojis)
    }

    func testUnknownCategoryWithoutQueryIsEmpty() {
        XCTAssertEqual(EmojiData.emojis(category: "nope", query: ""), [])
    }

    func testQuerySearchesAllCategoriesByKeyword() {
        let results = EmojiData.emojis(category: "smileys", query: "flower")
        XCTAssertTrue(results.contains("🌸"))
        XCTAssertTrue(results.contains("🌻"))
    }

    func testQueryFallsBackToUnicodeNames() {
        XCTAssertTrue(EmojiData.emojis(category: "smileys", query: "grinning").contains("😀"))
    }

    func testQueryIsCaseInsensitiveAndTrimmed() {
        XCTAssertEqual(EmojiData.emojis(category: "smileys", query: "  PUPPY "),
                       EmojiData.emojis(category: "smileys", query: "puppy"))
        XCTAssertFalse(EmojiData.emojis(category: "smileys", query: "puppy").isEmpty)
    }

    func testNoMatches() {
        XCTAssertEqual(EmojiData.emojis(category: "smileys", query: "zzqqxx"), [])
    }

    func testCategoryTitles() {
        XCTAssertEqual(EmojiData.categories.first?.title, "Smileys")
    }
}
