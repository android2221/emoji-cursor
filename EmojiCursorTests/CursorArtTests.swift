import XCTest
import ImageIO
import UniformTypeIdentifiers
@testable import EmojiCursor

/// Image loading, and choosing an image in `CursorManager`.
final class CursorArtTests: XCTestCase {
    private var directory: URL!
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CursorArtTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        suiteName = "EmojiCursorTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        defaults.removePersistentDomain(forName: suiteName)
        try super.tearDownWithError()
    }

    // MARK: - Loading

    func testLoadsStillPNGAndJPEG() throws {
        for type in [UTType.png, .jpeg] {
            let url = try writeImage(named: "still.\(type.preferredFilenameExtension!)", type: type)
            let art = try XCTUnwrap(CursorArt.image(contentsOf: url), "\(type)")
            XCTAssertEqual(art.frames.count, 1)
            XCTAssertFalse(art.isAnimated)
        }
    }

    func testLoadsAnimatedGIFWithFrameDelays() throws {
        let url = try writeImage(named: "anim.gif", type: .gif, frames: 3, delay: 0.2)
        let art = try XCTUnwrap(CursorArt.image(contentsOf: url))
        XCTAssertEqual(art.frames.count, 3)
        XCTAssertTrue(art.isAnimated)
        XCTAssertEqual(art.frameDurations.count, 3)
        for duration in art.frameDurations {
            XCTAssertEqual(duration, 0.2, accuracy: 0.001)
        }
    }

    func testSingleFrameGIFIsStill() throws {
        let url = try writeImage(named: "still.gif", type: .gif)
        let art = try XCTUnwrap(CursorArt.image(contentsOf: url))
        XCTAssertFalse(art.isAnimated)
    }

    func testScalesDownLargeImages() throws {
        let url = try writeImage(named: "big.png", type: .png, width: 1000, height: 500)
        let frame = try XCTUnwrap(CursorArt.image(contentsOf: url)?.frames.first)
        XCTAssertEqual(frame.width, CursorArt.maxPixelSize)
        XCTAssertEqual(frame.height, CursorArt.maxPixelSize / 2)
    }

    func testRejectsNonImagesAndOtherFormats() throws {
        let text = directory.appendingPathComponent("fake.png")
        try Data("not an image".utf8).write(to: text)
        XCTAssertNil(CursorArt.image(contentsOf: text))

        let tiff = try writeImage(named: "image.tiff", type: .tiff)
        XCTAssertNil(CursorArt.image(contentsOf: tiff))
    }

    func testTinyOrMissingDelaysUseBrowserDefault() {
        XCTAssertEqual(CursorArt.frameDuration(nil), 0.1)
        XCTAssertEqual(CursorArt.frameDuration(0), 0.1)
        XCTAssertEqual(CursorArt.frameDuration(0.01), 0.1)
        XCTAssertEqual(CursorArt.frameDuration(0.05), 0.05)
    }

    // MARK: - CursorManager

    @MainActor func testChosenImagePersistsAndSurvivesOriginalBeingDeleted() throws {
        let original = try writeImage(named: "pick.gif", type: .gif, frames: 2)
        let first = makeManager()
        XCTAssertFalse(first.usesImage)
        XCTAssertNil(first.imageURL)

        try first.selectImage(at: original)
        XCTAssertTrue(first.usesImage)
        let saved = try XCTUnwrap(first.imageURL)
        XCTAssertEqual(saved.deletingLastPathComponent().standardizedFileURL,
                       imagesDirectory.standardizedFileURL)

        try FileManager.default.removeItem(at: original)
        let second = makeManager()
        XCTAssertTrue(second.usesImage)
        XCTAssertEqual(second.imageURL, saved)
    }

    @MainActor func testPickingEmojiKeepsImageForLater() throws {
        let manager = makeManager()
        try manager.selectImage(at: writeImage(named: "pick.png", type: .png))
        manager.selectEmoji("🦊")
        XCTAssertFalse(manager.usesImage)
        XCTAssertNotNil(manager.imageURL)
        XCTAssertFalse(makeManager().usesImage)

        manager.useSavedImage()
        XCTAssertTrue(manager.usesImage)
        XCTAssertTrue(makeManager().usesImage)
    }

    @MainActor func testNewImageReplacesOldCopy() throws {
        let manager = makeManager()
        try manager.selectImage(at: writeImage(named: "a.png", type: .png))
        let old = try XCTUnwrap(manager.imageURL)
        try manager.selectImage(at: writeImage(named: "b.jpg", type: .jpeg))
        XCTAssertNotEqual(manager.imageURL, old)
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: imagesDirectory.path).count, 1)
    }

    @MainActor func testUnreadableFileIsRejectedWithoutChangingAnything() throws {
        let manager = makeManager()
        let bogus = directory.appendingPathComponent("bogus.gif")
        try Data("nope".utf8).write(to: bogus)
        XCTAssertThrowsError(try manager.selectImage(at: bogus)) { error in
            XCTAssertEqual(error as? CursorManager.ImageError, .unreadable)
        }
        XCTAssertFalse(manager.usesImage)
        XCTAssertNil(manager.imageURL)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: imagesDirectory.path), [])
    }

    @MainActor func testMissingSavedImageFallsBackToEmoji() throws {
        let manager = makeManager()
        try manager.selectImage(at: writeImage(named: "pick.png", type: .png))
        try FileManager.default.removeItem(at: XCTUnwrap(manager.imageURL))

        let reopened = makeManager()
        XCTAssertFalse(reopened.usesImage)
        XCTAssertNil(reopened.imageURL)
    }

    // MARK: - Helpers

    private var imagesDirectory: URL { directory.appendingPathComponent("Images", isDirectory: true) }

    @MainActor private func makeManager() -> CursorManager {
        CursorManager(defaults: defaults, reduceMotion: false, imageDirectory: imagesDirectory)
    }

    private func writeImage(named name: String, type: UTType, frames: Int = 1, delay: Double = 0.1,
                            width: Int = 16, height: Int = 16) throws -> URL {
        let url = directory.appendingPathComponent(name)
        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, frames, nil))
        for index in 0..<frames {
            let properties: [CFString: Any] = type == .gif
                ? [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]]
                : [:]
            let image = try makeImage(width: width, height: height, red: CGFloat(index) / CGFloat(frames))
            CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        }
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return url
    }

    private func makeImage(width: Int, height: Int, red: CGFloat) throws -> CGImage {
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: red, green: 0.5, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try XCTUnwrap(context.makeImage())
    }
}
