import Foundation

struct SpringPhysics {
    var target: CGPoint = .zero
    var current: CGPoint = .zero
    var velocity: CGPoint = .zero
    var stiffness: CGFloat = 0.35
    var damping: CGFloat = 0.75

    /// At rest on the target; stepping further won't move anything.
    var isSettled: Bool { current == target && velocity == .zero }

    /// Advance the spring one frame. Returns true if position changed.
    @discardableResult
    mutating func step(dt: CGFloat) -> Bool {
        let steps = dt * 60.0
        let dx = target.x - current.x
        let dy = target.y - current.y

        let dist = sqrt(dx * dx + dy * dy)
        let speed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
        if dist < 0.3 && speed < 0.3 {
            guard current != target else { return false }
            current = target
            velocity = .zero
            return true
        }

        velocity.x += dx * stiffness * steps
        velocity.y += dy * stiffness * steps
        velocity.x *= pow(damping, steps)
        velocity.y *= pow(damping, steps)
        current.x += velocity.x * steps
        current.y += velocity.y * steps
        return true
    }

    mutating func snap(to point: CGPoint) {
        target = point
        current = point
        velocity = .zero
    }
}
