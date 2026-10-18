public struct FingertipAssociation: Sendable {
    private var previous: FingertipDetection?
    private var lastSeen = -Double.infinity
    public init() {}
    /// Acquire automatically by confidence, then prefer the nearby detection to avoid identity swaps.
    public mutating func select(_ detections: [FingertipDetection], at time: Double) -> FingertipDetection? {
        if time - lastSeen > 250 { previous = nil }
        let selected: FingertipDetection?
        if let previous {
            selected = detections.filter { $0.point.distance(to: previous.point) <= 0.2 }
                .min { $0.point.distance(to: previous.point) < $1.point.distance(to: previous.point) }
        } else { selected = detections.max { $0.confidence < $1.confidence } }
        if let selected { previous = selected; lastSeen = time }
        return selected
    }
}
