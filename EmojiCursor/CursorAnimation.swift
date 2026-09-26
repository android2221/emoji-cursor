import Foundation

/// Time-driven "alive" idle motion and the click jiggle. Produces plain
/// numbers; `EmojiOverlay` turns them into a layer transform.
struct AnimationState {
    var aliveTime: Double = 0
    var jiggleTime: Double = 0

    private enum AliveParams {
        static let bobFrequency: Double = 2.5
        static let bobAmplitude: CGFloat = 2.0
        static let breatheFrequency: Double = 3.0
        static let breatheAmplitude: CGFloat = 0.04
        static let tiltFrequency: Double = 1.8
        static let tiltAmplitude: CGFloat = 0.06
    }

    private enum JiggleParams {
        static let duration: Double = 0.4
        static let rotationFrequency: Double = 40
        static let rotationAmplitude: CGFloat = 0.3
        static let bounceFrequency: Double = 25
        static let bounceAmplitude: CGFloat = 4.0
        static let squashFrequency: Double = 30
        static let squashAmplitude: CGFloat = 0.15
    }

    var isJiggling: Bool { jiggleTime > 0 }

    mutating func tick(dt: Double, aliveEnabled: Bool) {
        if aliveEnabled {
            aliveTime += dt
        }
        if jiggleTime > 0 {
            jiggleTime = max(jiggleTime - dt, 0)
        }
    }

    mutating func triggerJiggle() {
        jiggleTime = JiggleParams.duration
    }

    /// Gentle bob, breathe and tilt.
    var alive: (bobY: CGFloat, scale: CGFloat, tilt: CGFloat) {
        (bobY: CGFloat(sin(aliveTime * AliveParams.bobFrequency)) * AliveParams.bobAmplitude,
         scale: 1.0 + CGFloat(sin(aliveTime * AliveParams.breatheFrequency)) * AliveParams.breatheAmplitude,
         tilt: CGFloat(sin(aliveTime * AliveParams.tiltFrequency)) * AliveParams.tiltAmplitude)
    }

    /// Decaying wobble after a click; nil when no jiggle is running.
    var jiggle: (bounce: CGFloat, angle: CGFloat, squash: CGFloat)? {
        guard isJiggling else { return nil }
        let progress = jiggleTime / JiggleParams.duration
        let decay = CGFloat(progress * progress)
        return (bounce: CGFloat(sin(jiggleTime * JiggleParams.bounceFrequency)) * JiggleParams.bounceAmplitude * decay,
                angle: CGFloat(sin(jiggleTime * JiggleParams.rotationFrequency)) * JiggleParams.rotationAmplitude * decay,
                squash: 1.0 + CGFloat(sin(jiggleTime * JiggleParams.squashFrequency)) * JiggleParams.squashAmplitude * decay)
    }
}
