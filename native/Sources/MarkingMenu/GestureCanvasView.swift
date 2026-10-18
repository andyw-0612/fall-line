import AppKit
import MarkingCore

// Opaque AppKit token; it is only passed back to AppKit on the main queue.
// A Sendable holder allows Swift6.1's nonisolated deinit to schedule cleanup.
private struct NavigationMonitorToken: @unchecked Sendable {
    let rawValue: Any
}

@MainActor final class GestureCanvasView: NSView {
    let model: AppModel
    let style: GestureCanvasStyle
    var controlBounds: [CGRect] = []
    var inputEnabled = true
    var slowModeOverlayOpacity = 0.6
    private var touchStroke = TrackpadStroke()
    private var touchIdentities: Set<AnyHashable> = []
    private var tracking: NSTrackingArea?
    private var navigationMonitor: NavigationMonitorToken?
    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { style == .playground }
    init(model: AppModel, style: GestureCanvasStyle = .playground) {
        self.model = model; self.style = style; super.init(frame: .zero)
        if style == .product {
            wantsLayer = true
            layer?.backgroundColor = NSColor.clear.cgColor
        }
        model.focusCanvas = { [weak self] in guard let self else { return }; self.window?.makeFirstResponder(self) }
        allowedTouchTypes = .indirect; wantsRestingTouches = true
        setAccessibilityElement(true); setAccessibilityRole(.group); setAccessibilityLabel("Marking menu canvas")
        setAccessibilityHelp(style == .product
            ? "Hold and drag to give feedback. Left arrow shows the previous product; right arrow shows the next. Escape cancels feedback."
            : "Hold and drag to explore. Arrow keys choose directions, Return applies the final option, Escape cancels.")
    }
    required init?(coder: NSCoder) { nil }
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        if style == .product, !model.gesture.active, controlBounds.contains(where: { $0.contains(local) }) {
            return nil
        }
        return super.hitTest(point)
    }
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if let navigationMonitor { NSEvent.removeMonitor(navigationMonitor.rawValue); self.navigationMonitor = nil }
        super.viewWillMove(toWindow: newWindow)
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
        guard style == .product, window != nil else { return }
        // Keep browsing shortcuts available after buttons/settings had focus.
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let window = self.window, event.window === window, window.isKeyWindow,
                  !(window.firstResponder is NSTextView) else { return event }
            return self.handleProductNavigation(event) ? nil : event
        }
        navigationMonitor = monitor.map { NavigationMonitorToken(rawValue: $0) }
    }
    deinit {
        if let navigationMonitor {
            DispatchQueue.main.async { NSEvent.removeMonitor(navigationMonitor.rawValue) }
        }
    }

    @discardableResult func handleProductNavigation(_ event: NSEvent) -> Bool {
        guard style == .product, inputEnabled, model.inputAvailable, !model.inputConfigurationOpen,
              event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return false }
        let action: (() -> Void)?
        switch event.keyCode {
        case 123: action = model.onPreviousProduct
        case 124: action = model.onNextProduct
        default: return false
        }
        guard let action else { return false }
        if !event.isARepeat { action() }
        return true
    }
    override func layout() { super.layout(); model.resized(bounds.size); needsDisplay = true }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect], owner: self)
        addTrackingArea(area); tracking = area
    }
    private func point(_ event: NSEvent) -> Point { let p = convert(event.locationInWindow, from: nil); return Point(p.x, p.y) }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        guard inputEnabled else { return }
        window?.makeFirstResponder(self)
        guard model.inputMode == .mouse else { model.cancel(); return }
        model.begin(point(event), at: event.timestamp * 1000, input: .mouse)
    }
    override func mouseDragged(with event: NSEvent) {
        guard model.inputMode == .mouse else { return }; model.move(point(event), at: event.timestamp * 1000, down: true, input: .mouse)
    }
    override func mouseUp(with event: NSEvent) {
        guard model.inputMode == .mouse else { return }; model.end(point(event), at: event.timestamp * 1000, input: .mouse)
    }
    override func mouseMoved(with event: NSEvent) {
        guard inputEnabled else { return }
        model.move(point(event), at: event.timestamp * 1000, down: false, input: .mouse)
    }
    override func keyDown(with event: NSEvent) {
        guard inputEnabled else { return }
        switch event.keyCode {
        case 53: model.escape(); touchStroke.reset(); touchIdentities = []
        case 123:
            if style == .product { if !event.isARepeat { model.onPreviousProduct?() } }
            else { model.choose(.left) }
        case 124:
            if style == .product { if !event.isARepeat { model.onNextProduct?() } }
            else { model.choose(.right) }
        case 125: model.choose(.down)
        case 126: model.choose(.up)
        case 36, 76: model.confirmKeyboardSelection()
        default: super.keyDown(with: event)
        }
    }
    // Scroll events (including momentum) never drive the marking engine.
    override func scrollWheel(with event: NSEvent) { if model.inputMode != .trackpad { super.scrollWheel(with: event) } }
    override func touchesBegan(with event: NSEvent) { updateTouches(event) }
    override func touchesMoved(with event: NSEvent) { updateTouches(event) }
    override func touchesEnded(with event: NSEvent) { updateTouches(event) }
    override func touchesCancelled(with event: NSEvent) { touchStroke.reset(); touchIdentities = []; model.cancel() }
    private func updateTouches(_ event: NSEvent) {
        guard model.inputMode == .trackpad else { touchStroke.reset(); touchIdentities = []; return }
        window?.makeFirstResponder(self)
        let touches = event.touches(matching: .touching, in: self)
        let identities = Set(touches.compactMap { $0.identity as? AnyHashable })
        if touches.count == 2 && touchIdentities.count == 2 && identities != touchIdentities {
            model.cancel(); touchStroke.invalidateUntilLift()
        }
        touchIdentities = identities
        let centroid = touches.count == 2 ? Point(touches.reduce(0) { $0 + $1.normalizedPosition.x } / 2,
                                                  touches.reduce(0) { $0 + $1.normalizedPosition.y } / 2) : nil
        touchStroke.sensitivity = model.trackpadSensitivity
        for action in touchStroke.update(count: touches.count, centroid: centroid, origin: point(event)) {
            switch action {
            case let .begin(p): model.begin(p, at: event.timestamp * 1000, input: .trackpad)
            case let .move(p): model.move(p, at: event.timestamp * 1000, down: true, input: .trackpad)
            case let .finish(p): model.end(p, at: event.timestamp * 1000, input: .trackpad)
            case .cancel: model.cancel()
            }
        }
    }
    func refreshAccessibility() {
        setAccessibilityValue(model.gesture.active ? model.gesture.path.map(\.name).joined(separator: ", ") : "No menu open")
        setAccessibilityCustomActions(model.gesture.active ? model.options.map { option in
            NSAccessibilityCustomAction(name: option.isBack ? "Go back" : model.gesture.final ? "Select \(option.name)" : "Choose \(option.name)") { [weak self] in
                guard let self else { return false }
                if self.model.gesture.final && !option.isBack { self.model.confirmKeyboardSelection() }
                else { self.model.choose(option.direction) }
                return true
            }
        } : [])
    }
    override func draw(_ dirtyRect: NSRect) {
        if style == .playground { NSColor.white.setFill(); bounds.fill() }
        else {
            // The transparent input surface must not retain snapshots of the
            // moving scene underneath it when the camera animation finishes.
            NSGraphicsContext.current?.cgContext.clear(bounds)
        }
        let gesture = model.gesture, centers = model.centers
        if style == .product, gesture.active, gesture.mode == .slow {
            NSColor(srgbRed: 0.12, green: 0.20, blue: 0.18, alpha: min(1, max(0, slowModeOverlayOpacity))).setFill()
            bounds.fill()
        }
        if gesture.active, let firstCenter = centers.first {
            NSGraphicsContext.saveGraphicsState()
            if gesture.mode == .slow, let center = centers.last {
                // Cut the buttons out of the trail's drawing region. Their
                // translucent fills should reveal the product, never the line.
                let visibleTrail = NSBezierPath(rect: bounds)
                visibleTrail.windingRule = .evenOdd
                for option in model.options {
                    visibleTrail.appendRect(model.optionRect(option, center: center).insetBy(dx: -6, dy: -6))
                }
                visibleTrail.addClip()
            }
            let origin = gesture.mode == .fast ? gesture.stroke.first ?? firstCenter : firstCenter
            let line = NSBezierPath()
            line.lineWidth = style == .product ? (gesture.mode == .slow ? 1.5 : 3) : 1
            line.lineCapStyle = .round; line.lineJoinStyle = .round
            line.move(to: NSPoint(x: origin.x, y: origin.y))
            let trail = gesture.mode == .fast ? gesture.stroke : centers
            if gesture.mode == .fast, let first = trail.first { line.move(to: NSPoint(x: first.x, y: first.y)) }
            for center in trail.dropFirst() { line.line(to: NSPoint(x: center.x, y: center.y)) }
            line.line(to: NSPoint(x: gesture.pointer.x, y: gesture.pointer.y))
            let trailColor: NSColor = style == .product ? (gesture.mode == .slow ? .white.withAlphaComponent(0.85) : .black) : .gray
            trailColor.setStroke(); line.stroke()
            if style == .playground {
                NSColor.white.setFill(); let circle = NSBezierPath(ovalIn: NSRect(x: origin.x - 4, y: origin.y - 4, width: 8, height: 8)); circle.fill(); circle.stroke()
            }
            NSGraphicsContext.restoreGraphicsState()
        }
        if gesture.active && gesture.mode == .slow, let center = centers.last {
            for option in model.options {
                let rect = model.optionRect(option, center: center)
                let selected = gesture.final && !option.isBack && gesture.pending?.isBack != true
                let border = NSBezierPath(roundedRect: rect, xRadius: 10 * model.menuScale, yRadius: 10 * model.menuScale)
                if style == .product {
                    NSColor.white.withAlphaComponent(selected ? 0.22 : 0.025).setFill(); border.fill()
                    NSColor.white.withAlphaComponent(option.isBack ? 0.6 : 1).setStroke()
                } else {
                    (selected ? NSColor.black : .white).setFill(); border.fill()
                    (option.isBack ? NSColor.lightGray : .black).setStroke()
                }
                border.lineWidth = max(1.25, (gesture.pending?.direction == option.direction ? 2.5 : 1.75) * model.menuScale); border.stroke()
                let title = (style == .product ? option.name : "\(option.direction.arrow)  \(option.name)") as NSString
                let ink: NSColor = style == .product ? .white : selected ? .white : option.isBack ? .gray : .black
                let attributes: [NSAttributedString.Key: Any] = [.font: model.menuFont, .foregroundColor: ink]
                let size = title.size(withAttributes: attributes)
                title.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2), withAttributes: attributes)
            }
            if style == .playground {
                NSColor.white.setFill(); NSRect(x: center.x - 7, y: center.y - 7, width: 14, height: 14).fill()
                ("+" as NSString).draw(at: NSPoint(x: center.x - 5, y: center.y - 10), withAttributes: [.font: NSFont.systemFont(ofSize: 17), .foregroundColor: NSColor.darkGray])
            } else {
                let cross = NSBezierPath()
                cross.lineWidth = 1.5
                cross.lineCapStyle = .round
                cross.move(to: NSPoint(x: center.x - 5, y: center.y))
                cross.line(to: NSPoint(x: center.x + 5, y: center.y))
                cross.move(to: NSPoint(x: center.x, y: center.y - 5))
                cross.line(to: NSPoint(x: center.x, y: center.y + 5))
                NSColor.white.setStroke(); cross.stroke()
            }
        }

    }
}
