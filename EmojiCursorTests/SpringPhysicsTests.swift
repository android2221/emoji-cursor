import XCTest
@testable import EmojiCursor

final class SpringPhysicsTests: XCTestCase {
    private let frame: CGFloat = 1.0 / 60.0

    func testSnapMovesImmediatelyAndClearsVelocity() {
        var spring = SpringPhysics()
        spring.velocity = CGPoint(x: 5, y: 5)
        spring.snap(to: CGPoint(x: 100, y: 50))
        XCTAssertEqual(spring.current, CGPoint(x: 100, y: 50))
        XCTAssertEqual(spring.target, CGPoint(x: 100, y: 50))
        XCTAssertEqual(spring.velocity, .zero)
    }

    func testStepAtRestReportsNoChange() {
        var spring = SpringPhysics()
        spring.snap(to: CGPoint(x: 10, y: 10))
        XCTAssertFalse(spring.step(dt: frame))
    }

    func testStepMovesTowardTarget() {
        var spring = SpringPhysics()
        spring.target = CGPoint(x: 100, y: 0)
        XCTAssertTrue(spring.step(dt: frame))
        XCTAssertGreaterThan(spring.current.x, 0)
        XCTAssertLessThanOrEqual(spring.current.x, 100)
    }

    func testConvergesExactlyOnTarget() {
        var spring = SpringPhysics()
        spring.target = CGPoint(x: 200, y: -80)
        for _ in 0..<600 { spring.step(dt: frame) }
        XCTAssertEqual(spring.current, spring.target)
        XCTAssertEqual(spring.velocity, .zero)
    }

    func testSmallGapSnapsToTarget() {
        var spring = SpringPhysics()
        spring.target = CGPoint(x: 0.1, y: 0.1)
        XCTAssertTrue(spring.step(dt: frame))
        XCTAssertEqual(spring.current, spring.target)
    }

    func testFrameRateIndependenceIsApproximate() {
        // Two half-length frames should land near one full frame.
        var a = SpringPhysics(), b = SpringPhysics()
        a.target = CGPoint(x: 100, y: 0); b.target = a.target
        a.step(dt: frame)
        b.step(dt: frame / 2); b.step(dt: frame / 2)
        XCTAssertEqual(a.current.x, b.current.x, accuracy: 25)
    }
}
