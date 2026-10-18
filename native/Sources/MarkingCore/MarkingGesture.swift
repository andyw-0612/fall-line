import Foundation

// Slow exploration uses heading and pause intent; expert strokes use whole-path recognition.
// Pure recognition stays independent of AppKit, camera capture, and drawing.
public final class MarkingGesture {
    public enum Mode: String { case probing, slow, fast }
    public struct Pending {
        public let direction: Direction
        public let isBack: Bool
        let point: Point
        let due: Double
    }
    private struct Candidate {
        var direction: Direction; var from: Point; var length: Double
    }
    public private(set) var active = false
    public private(set) var mode: Mode = .slow
    public private(set) var stack: [GestureVertex] = []
    public private(set) var pointer = Point.zero
    public private(set) var pending: Pending?
    public var canEnter: (Direction, Point, Point) -> Bool
    private let adaptive: Bool
    private let root: MenuNode
    private let transitionDelay: Double
    private let backDelay: Double
    private var sample = Point.zero
    private var startedAt = 0.0, lastMotion = 0.0
    private var heading: Direction?
    private var motionAnchor = Point.zero
    private var repeatArmed = false
    private var candidate: Candidate?
    public private(set) var stroke: [Point] = []
    private var dwellAnchor = Point.zero
    private var dwellStartedAt = 0.0
    private let noviceDelay = 1000.0 / 3
    public var current: GestureVertex? { stack.last }
    public var final: Bool { active && current?.node.isLeaf == true }
    public var path: [MenuNode] { stack.dropFirst().map(\.node) }
    public init(root: MenuNode = .root, adaptive: Bool = false, transitionDelay: Double = 100, backDelay: Double = 140,
                canEnter: @escaping (Direction, Point, Point) -> Bool = { _, _, _ in true }) {
        self.root = root; self.adaptive = adaptive; self.transitionDelay = transitionDelay; self.backDelay = backDelay; self.canEnter = canEnter
    }
    public func start(_ point: Point, at time: Double) {
        mode = adaptive ? .probing : .slow; startedAt = time; lastMotion = time
        active = true; stack = [GestureVertex(node: root, incoming: nil, point: point)]
        sample = point; pointer = point; heading = nil; candidate = nil; pending = nil
        motionAnchor = point; repeatArmed = false
        stroke = [point]; dwellAnchor = point; dwellStartedAt = time
    }
    @discardableResult public func move(_ point: Point, at time: Double) -> Bool {
        guard active else { return false }
        pointer = point
        if adaptive && mode != .slow {
            if stroke.last != point { stroke.append(point) }
            if mode == .probing {
                if time - startedAt >= noviceDelay { mode = .slow }
                else if point.distance(to: stack[0].point) >= 5 {
                    mode = .fast; dwellAnchor = point; dwellStartedAt = time
                }
            } else if point.distance(to: dwellAnchor) >= 3 {
                dwellAnchor = point; dwellStartedAt = time
            }
            if mode != .slow { return true }
        }
        // A pause is measured from meaningful motion, not tiny per-frame jitter or
        // the delayed menu transition. Once armed it survives the next small samples.
        if time - lastMotion >= 180 { repeatArmed = true }
        if point.distance(to: motionAnchor) >= 3 { motionAnchor = point; lastMotion = time }
        let dx = point.x - sample.x, dy = point.y - sample.y, distance = hypot(dx, dy)
        guard distance >= 1 else { return false }
        let from = sample; sample = point
        if let p = pending {
            let across = p.direction.horizontal ? abs(point.y - p.point.y) : abs(point.x - p.point.x)
            let along = (p.direction.horizontal ? point.x - p.point.x : point.y - p.point.y) * p.direction.sign
            if (across >= 12 && across > abs(along) * 0.8) || along <= -12 { pending = nil; candidate = nil }
            else { return advance(at: time) }
        }
        let paused = repeatArmed
        let ax = abs(dx), ay = abs(dy)
        let direction: Direction
        if ax > ay * 1.15 { direction = dx > 0 ? .right : .left }
        else if ay > ax * 1.15 { direction = dy > 0 ? .down : .up }
        else {
            let preferred = candidate?.direction ?? heading
            if let preferred, preferred.horizontal, (dx > 0 ? 1.0 : dx < 0 ? -1 : 0) == preferred.sign { direction = preferred }
            else if let preferred, !preferred.horizontal, (dy > 0 ? 1.0 : dy < 0 ? -1 : 0) == preferred.sign { direction = preferred }
            else { direction = ay >= ax ? (dy > 0 ? .down : .up) : (dx > 0 ? .right : .left) }
        }
        if direction == heading && !paused && candidate == nil { return false }
        if candidate?.direction != direction {
            candidate = nil
            if direction == heading && !paused { return false }
            candidate = Candidate(direction: direction, from: from, length: 0)
        }
        guard var intent = candidate else { return false }
        intent.length += distance; candidate = intent
        let nx = point.x - intent.from.x, ny = point.y - intent.from.y
        let progress = direction.horizontal ? abs(nx) : abs(ny)
        guard progress >= 6 && hypot(nx, ny) / intent.length >= 0.85 else { return false }
        let isBack = current?.incoming?.opposite == direction
        if final && !isBack { return false }
        if !canEnter(direction, from, pointer) { return false }
        candidate = nil
        pending = Pending(direction: direction, isBack: isBack, point: point, due: time + (isBack ? backDelay : transitionDelay))
        return advance(at: time)
    }
    @discardableResult public func advance(at time: Double) -> Bool {
        guard active else { return false }
        var revealed = false
        if adaptive && mode == .probing && time - startedAt >= noviceDelay {
            mode = .slow; revealed = true
        } else if adaptive && mode == .fast && time - dwellStartedAt >= noviceDelay {
            // Interpret the hidden stroke once, then reveal the reached level at the pointer.
            // If the shape was invalid, keep it unselected and let release cancel it.
            guard let recognized = StrokeRecognizer.vertices(stroke, root: root) else { return false }
            stack = recognized
            if !stack.isEmpty { stack[stack.count - 1].point = pointer }
            heading = recognized.last?.incoming
            sample = pointer; lastMotion = dwellStartedAt; candidate = nil; pending = nil
            motionAnchor = pointer; repeatArmed = true
            mode = .slow; revealed = true
        }
        if mode == .slow, time - lastMotion >= 180 { repeatArmed = true }
        guard let p = pending, time >= p.due else { return revealed }
        pending = nil
        return navigate(p.direction, isBack: p.isBack, at: time, point: pointer, resetMotion: false)
    }
    @discardableResult public func commit(_ direction: Direction, isBack: Bool, at time: Double, point: Point) -> Bool {
        // Explicit navigation (keyboard/accessibility) uses the visible menu, not a stroke.
        navigate(direction, isBack: isBack, at: time, point: point, resetMotion: true)
    }
    private func navigate(_ direction: Direction, isBack: Bool, at time: Double, point: Point, resetMotion: Bool) -> Bool {
        let next = current?.node.choices(incoming: current?.incoming).first(where: { $0.direction == direction })?.node
        guard isBack ? stack.count > 1 : next != nil else { return false }
        mode = .slow
        pointer = point
        heading = direction; repeatArmed = false; candidate = nil
        if resetMotion { lastMotion = time; motionAnchor = point }
        if isBack && stack.count > 1 { stack.removeLast(); stack[stack.count - 1].point = point; return true }
        guard let node = next else { return false }
        stack.append(GestureVertex(node: node, incoming: direction, point: point)); return true
    }
    public func finish() -> [MenuNode]? {
        guard active else { return nil }
        // A sub-threshold startup scribble must not become a complete hidden gesture.
        if adaptive && mode == .probing { active = false; pending = nil; return nil }
        if adaptive && mode != .slow {
            if let recognized = StrokeRecognizer.vertices(stroke, root: root) { stack = recognized }
            else { active = false; pending = nil; return nil }
        }
        let result = final && pending?.isBack != true ? path : nil
        active = false; pending = nil; return result
    }
    public func cancel() { active = false; pending = nil }
}
