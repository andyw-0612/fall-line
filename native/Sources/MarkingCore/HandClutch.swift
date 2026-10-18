public final class HandClutch {
    public enum Mode: String, CaseIterable, Sendable { case dwell = "Dwell", clutch = "Space" }
    public enum Action: Equatable { case begin(Point, Double), move(Point, Double, Bool), finish(Point, Double), cancel }
    public private(set) var down = false
    public private(set) var point: Point?
    public private(set) var previousPose: HandPose?
    public var mode: Mode = .dwell
    private var space = false, ready = false
    private var lastTime: Double?
    private var stationary: (point: Point, since: Double)?
    private var finishStationary: (point: Point, since: Double)?
    private var cooldown = -Double.infinity
    public init() {}
    @discardableResult public func cancel() -> [Action] {
        let result: [Action] = down ? [.cancel] : []
        down = false; space = false; point = nil; previousPose = nil; stationary = nil; finishStationary = nil; ready = false; cooldown = -.infinity; lastTime = nil
        return result
    }
    public func didFinish(committed: Bool, at time: Double) {
        down = false; stationary = nil; finishStationary = nil; ready = false; cooldown = time + (committed ? 1500 : 200)
    }
    /// Retain the active stroke and Space state, but never count missing data as a dwell.
    public func pauseTracking(at time: Double) {
        stationary = nil; finishStationary = nil; ready = false; lastTime = time
    }
    public func setSpace(_ held: Bool, at time: Double) -> [Action] {
        space = held
        guard mode == .clutch, let point, let lastTime, time - lastTime <= 250 else { return [] }
        if held && !down { down = true; return [.begin(point, time)] }
        if !held && down && previousPose?.pinched != true { down = false; return [.finish(point, time)] }
        return []
    }
    /// A nil pose supports a fingertip-only detector: dwell or Space, without inferring hidden joints.
    public func update(_ point: Point, pose: HandPose? = nil, at time: Double, final: Bool) -> [Action] {
        var actions: [Action] = []
        if let lastTime, time - lastTime > 250 { actions += cancel() }
        let previousPoint = self.point, previousTime = lastTime, previousPose = self.previousPose
        self.point = point; lastTime = time; self.previousPose = pose
        if mode == .clutch {
            let engaged = space || pose?.pinched == true
            if engaged && !down { down = true; actions.append(.begin(point, time)) }
            if !engaged && down { down = false; actions.append(.finish(point, time)) }
            else { actions.append(.move(point, time, down)) }
            return actions
        }
        if down {
            if let pose, !pose.indexExtended { down = false; return actions + [.finish(previousPoint ?? point, time)] }
            actions.append(.move(point, time, true))
            if final {
                if let hold = finishStationary, point.distance(to: hold.point) < 2.5 {
                    if time - hold.since >= 320 { down = false; actions.append(.finish(point, time)) }
                } else { finishStationary = (point, time) }
            } else { finishStationary = nil }
            return actions
        }
        actions.append(.move(point, time, false))
        guard pose?.pointing ?? true else { stationary = nil; ready = false; return actions }
        if pose != nil, let previousPose, !previousPose.pointing { down = true; stationary = nil; ready = false; return actions + [.begin(point, time)] }
        guard time >= cooldown else { return actions }
        if let still = stationary {
            if point.distance(to: still.point) < 2.5 { if time - still.since >= 200 { ready = true } }
            else if ready {
                down = true; ready = false; stationary = nil
                actions += [.begin(still.point, previousTime ?? time), .move(point, time, true)]
            } else { stationary = (point, time) }
        } else { stationary = (point, time) }
        return actions
    }
}
