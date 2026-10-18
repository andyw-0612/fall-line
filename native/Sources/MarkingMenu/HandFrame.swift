import Foundation
import MarkingCore

struct HandFrame: Sendable {
    /// Normalized, top-left coordinates in the unmirrored camera frame.
    let tip: Point?
    let confidence: Double
    let time: Double
    let aspect: Double
    let error: String?
    var isHeld = false
    var landmarks: [Point] = []
    var isSynthetic = false

    static func indexTip(in landmarks: [Point]) -> Point? {
        guard landmarks.count == 21 else { return nil }
        let tip = landmarks[8]
        return tip.x.isFinite && tip.y.isFinite && (0...1).contains(tip.x) && (0...1).contains(tip.y) ? tip : nil
    }
}
