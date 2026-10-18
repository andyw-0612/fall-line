import CoreGraphics

// Legacy name retained so proven input adapters stay source-compatible.
struct PinchEvent {
    enum Kind: String { case begin, move, end, cancel }
    let kind: Kind
    let position: CGPoint
}

