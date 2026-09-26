import Foundation

/// Recent emoji positions, used to draw fading copies behind it.
struct TailTrail {
    /// Number of tail layers allocated per screen (the tail-length slider's ceiling).
    static let maxSlots = 20
    /// Frames between consecutive tail copies.
    static let spacing = 4

    /// Positions, newest first.
    private(set) var history: [CGPoint] = []

    mutating func record(_ position: CGPoint, length: Int) {
        guard length > 0 else { return }
        history.insert(position, at: 0)
        let needed = length * Self.spacing + 1
        if history.count > needed {
            history.removeSubrange(needed...)
        }
    }

    mutating func clear() {
        history.removeAll()
    }

    /// Where tail copy `slot` should be drawn, or nil if it should be hidden.
    func position(forSlot slot: Int, length: Int) -> CGPoint? {
        guard slot < length else { return nil }
        let index = (slot + 1) * Self.spacing
        return index < history.count ? history[index] : nil
    }

    static func opacity(forSlot slot: Int, length: Int) -> Float {
        Float(length - slot) / Float(length + 1) * 0.6
    }

    static func scale(forSlot slot: Int) -> CGFloat {
        1.0 - 0.4 * CGFloat(slot + 1) / CGFloat(maxSlots)
    }

    /// True once every copy has caught up with `position`, so nothing moves.
    func isSettled(at position: CGPoint) -> Bool {
        history.allSatisfy { $0 == position }
    }
}
