import XCTest
@testable import EmojiCursor

/// Needs AppKit, so runs only in the Xcode test target.
///
/// Note: `register(defaults:)` writes to the process-wide registration
/// domain, so these tests rely on every `CursorManager.init` registering
/// right before it reads.
final class CursorManagerSettingsTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "EmojiCursorTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    @MainActor func testFreshInstallDefaults() {
        let manager = CursorManager(defaults: defaults, reduceMotion: false)
        XCTAssertEqual(manager.currentEmoji, "😀")
        XCTAssertEqual(manager.emojiSize, 28)
        XCTAssertTrue(manager.springEnabled)
        XCTAssertTrue(manager.jiggleOnClick)
        XCTAssertFalse(manager.aliveMotion)
        XCTAssertEqual(manager.tailLength, 0)
    }

    @MainActor func testReduceMotionTurnsMotionEffectsOffByDefault() {
        let manager = CursorManager(defaults: defaults, reduceMotion: true)
        XCTAssertFalse(manager.springEnabled)
        XCTAssertFalse(manager.jiggleOnClick)
        XCTAssertFalse(manager.aliveMotion)
    }

    @MainActor func testReduceMotionDoesNotOverrideExplicitChoices() {
        defaults.set(true, forKey: CursorManager.DefaultsKey.springEnabled)
        let manager = CursorManager(defaults: defaults, reduceMotion: true)
        XCTAssertTrue(manager.springEnabled)
    }

    @MainActor func testSettingsPersistAcrossInstances() {
        let first = CursorManager(defaults: defaults, reduceMotion: false)
        first.selectEmoji("🦊")
        first.emojiSize = 40
        first.tailLength = 5
        first.aliveMotion = true
        first.springEnabled = false
        first.jiggleOnClick = false

        let second = CursorManager(defaults: defaults, reduceMotion: false)
        XCTAssertEqual(second.currentEmoji, "🦊")
        XCTAssertEqual(second.emojiSize, 40)
        XCTAssertEqual(second.tailLength, 5)
        XCTAssertTrue(second.aliveMotion)
        XCTAssertFalse(second.springEnabled)
        XCTAssertFalse(second.jiggleOnClick)
    }

    @MainActor func testExistingInstallIsDetectedFromSavedEmoji() {
        XCTAssertFalse(AppDelegate.isExistingInstall(defaults: defaults, domain: suiteName))
        _ = CursorManager(defaults: defaults, reduceMotion: false)  // registration alone doesn't count
        XCTAssertFalse(AppDelegate.isExistingInstall(defaults: defaults, domain: suiteName))
        defaults.set("🦊", forKey: CursorManager.DefaultsKey.lastEmoji)
        XCTAssertTrue(AppDelegate.isExistingInstall(defaults: defaults, domain: suiteName))
    }

    @MainActor func testReadsSizeSavedByEarlierVersions() {
        // Older builds stored the size as a CGFloat.
        defaults.set(CGFloat(36), forKey: CursorManager.DefaultsKey.emojiSize)
        XCTAssertEqual(CursorManager(defaults: defaults, reduceMotion: false).emojiSize, 36)
    }
}
