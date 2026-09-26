import XCTest
@testable import EmojiCursor

final class TailTrailTests: XCTestCase {
    private func point(_ x: CGFloat) -> CGPoint { CGPoint(x: x, y: 0) }

    func testRecordsNothingWhenTailIsOff() {
        var trail = TailTrail()
        trail.record(point(1), length: 0)
        XCTAssertTrue(trail.history.isEmpty)
    }

    func testHistoryIsNewestFirstAndCappedToWhatTheTailNeeds() {
        var trail = TailTrail()
        for x in 0..<100 { trail.record(point(CGFloat(x)), length: 2) }
        // 2 slots × spacing 4, plus the current position.
        XCTAssertEqual(trail.history.count, 2 * TailTrail.spacing + 1)
        XCTAssertEqual(trail.history.first, point(99))
    }

    func testSlotPositionsAreSampledEverySpacingFrames() {
        var trail = TailTrail()
        for x in 0..<100 { trail.record(point(CGFloat(x)), length: 3) }
        XCTAssertEqual(trail.position(forSlot: 0, length: 3), point(99 - 4))
        XCTAssertEqual(trail.position(forSlot: 1, length: 3), point(99 - 8))
        XCTAssertEqual(trail.position(forSlot: 2, length: 3), point(99 - 12))
    }

    func testSlotsBeyondLengthOrHistoryAreHidden() {
        var trail = TailTrail()
        for x in 0..<6 { trail.record(point(CGFloat(x)), length: 5) }
        XCTAssertNotNil(trail.position(forSlot: 0, length: 5))
        XCTAssertNil(trail.position(forSlot: 1, length: 5), "not enough history yet")
        XCTAssertNil(trail.position(forSlot: 5, length: 5), "slot past the tail length")
    }

    func testOpacityFadesAlongTheTail() {
        XCTAssertEqual(TailTrail.opacity(forSlot: 0, length: 3), 3.0 / 4.0 * 0.6, accuracy: 1e-6)
        XCTAssertEqual(TailTrail.opacity(forSlot: 2, length: 3), 1.0 / 4.0 * 0.6, accuracy: 1e-6)
        XCTAssertGreaterThan(TailTrail.opacity(forSlot: 0, length: 3), TailTrail.opacity(forSlot: 1, length: 3))
    }

    func testScaleShrinksTowardTheEnd() {
        XCTAssertEqual(TailTrail.scale(forSlot: 0), 1 - 0.4 / CGFloat(TailTrail.maxSlots), accuracy: 1e-9)
        XCTAssertEqual(TailTrail.scale(forSlot: TailTrail.maxSlots - 1), 0.6, accuracy: 1e-9)
    }

    func testSettledOnceEveryEntryHasCaughtUp() {
        var trail = TailTrail()
        XCTAssertTrue(trail.isSettled(at: point(5)), "empty trail has nothing to animate")
        trail.record(point(1), length: 1)
        trail.record(point(5), length: 1)
        XCTAssertFalse(trail.isSettled(at: point(5)))
        for _ in 0..<TailTrail.spacing { trail.record(point(5), length: 1) }
        XCTAssertTrue(trail.isSettled(at: point(5)))
    }

    func testClear() {
        var trail = TailTrail()
        trail.record(point(1), length: 1)
        trail.clear()
        XCTAssertTrue(trail.history.isEmpty)
    }
}
