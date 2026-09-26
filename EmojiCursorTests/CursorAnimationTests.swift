import XCTest
@testable import EmojiCursor

final class AnimationStateTests: XCTestCase {
    func testAliveTimeOnlyAdvancesWhenEnabled() {
        var state = AnimationState()
        state.tick(dt: 0.5, aliveEnabled: false)
        XCTAssertEqual(state.aliveTime, 0)
        state.tick(dt: 0.5, aliveEnabled: true)
        XCTAssertEqual(state.aliveTime, 0.5)
    }

    func testJiggleRunsForItsDurationThenStops() {
        var state = AnimationState()
        XCTAssertFalse(state.isJiggling)
        XCTAssertNil(state.jiggle)

        state.triggerJiggle()
        XCTAssertTrue(state.isJiggling)
        state.tick(dt: 0.1, aliveEnabled: false)
        XCTAssertNotNil(state.jiggle)

        state.tick(dt: 1.0, aliveEnabled: false)
        XCTAssertEqual(state.jiggleTime, 0)
        XCTAssertFalse(state.isJiggling)
        XCTAssertNil(state.jiggle)
    }

    func testJiggleDecaysTowardTheEnd() {
        var early = AnimationState(), late = AnimationState()
        early.triggerJiggle(); late.triggerJiggle()
        late.tick(dt: 0.35, aliveEnabled: false)
        // Envelope (progress²) is what bounds the amplitude.
        XCTAssertLessThan(abs(late.jiggle!.bounce), 4.0 * 0.02)
        XCTAssertLessThanOrEqual(abs(early.jiggle!.bounce), 4.0)
    }

    func testAliveMotionIsIdentityAtTimeZero() {
        let alive = AnimationState().alive
        XCTAssertEqual(alive.bobY, 0)
        XCTAssertEqual(alive.scale, 1)
        XCTAssertEqual(alive.tilt, 0)
    }

    func testAliveMotionStaysSubtle() {
        var state = AnimationState()
        for _ in 0..<500 {
            state.tick(dt: 1.0 / 60.0, aliveEnabled: true)
            let alive = state.alive
            XCTAssertLessThanOrEqual(abs(alive.bobY), 2.0)
            XCTAssertEqual(alive.scale, 1, accuracy: 0.04 + 1e-9)
            XCTAssertLessThanOrEqual(abs(alive.tilt), 0.06 + 1e-9)
        }
    }
}

final class SpringSettledTests: XCTestCase {
    func testSettledOnlyWhenAtTargetWithNoVelocity() {
        var spring = SpringPhysics()
        XCTAssertTrue(spring.isSettled)
        spring.target = CGPoint(x: 50, y: 0)
        XCTAssertFalse(spring.isSettled)
        for _ in 0..<600 { spring.step(dt: 1.0 / 60.0) }
        XCTAssertTrue(spring.isSettled)
    }
}
