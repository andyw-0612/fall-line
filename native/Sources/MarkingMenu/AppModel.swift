import SwiftUI
import MarkingCore

@MainActor @Observable final class AppModel {
    static let shared = AppModel()
    let gesture = MarkingGesture(adaptive: true)
    var inputConfigurationOpen = false
    var inputAvailable = true { didSet { if !inputAvailable { cancel() } } }
    @ObservationIgnored var onNextProduct: (() -> Void)?
    @ObservationIgnored var onPreviousProduct: (() -> Void)?
    var inputMode: InputMode = .mouse
    var history: [HistoryEntry] = []
    @ObservationIgnored var onSelection: ((HistoryEntry) -> Void)?
    @ObservationIgnored var onUndoSelection: ((Int) -> Void)?
    var revision = 0
    var width = 1100.0
    var height = 760.0
    var message = ""
    var trackpadSensitivity = 0.75
    var menuPadding = 16.0
    var menuScale = 1.0
    @ObservationIgnored var focusCanvas: (() -> Void)?
    private var source: InputMode?
    private var nextID = 1
    private var undo = ScribbleUndo()
    private var animation: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var previousMouseCoalescing: Bool?
    private let gestureTraces = GestureTraceStore()
    private var gestureSamples: [GestureSample] = []
    private var gestureSampleStart = 0.0
    static var now: Double { ProcessInfo.processInfo.systemUptime * 1000 }
    init() {
        gesture.canEnter = { [weak self] direction, _, point in
            guard let self, let center = self.centers.last, let option = self.options.first(where: { $0.direction == direction }) else { return false }
            return MenuGeometry.reaches(direction, center: center, point: point, box: self.optionRect(option, center: center))
        }
    }
    var centers: [Point] { MenuGeometry.centers(gesture.stack, width: width, height: height) }
    var options: [MenuChoice] {
        guard let current = gesture.current else { return [] }
        if gesture.final, let incoming = current.incoming {
            return [MenuChoice(direction: incoming, node: current.node), MenuChoice(direction: incoming.opposite, node: nil, isBack: true)]
        }
        return current.node.choices(incoming: current.incoming)
    }
    var menuFont: NSFont {
        NSFont(descriptor: MenuStyle.font.fontDescriptor, size: MenuStyle.font.pointSize * menuScale) ?? MenuStyle.font
    }
    func optionRect(_ option: MenuChoice, center: Point) -> CGRect {
        let textWidth = ("\(option.direction.arrow)  \(option.name)" as NSString).size(withAttributes: [.font: menuFont]).width
        return MenuGeometry.optionRect(direction: option.direction, center: center, width: width, height: height, labelWidth: max(200 * menuScale, textWidth + menuPadding * 2 * menuScale), labelHeight: (14 + menuPadding * 2) * menuScale, centerGap: 165 * menuScale)
    }
    func resized(_ size: CGSize) {
        guard size.width != width || size.height != height else { return }
        cancel(); width = size.width; height = size.height; revision += 1
    }
    @discardableResult func begin(_ point: Point, at time: Double, input: InputMode) -> Bool {
        if gesture.active { cancel() }
        if input == .mouse {
            previousMouseCoalescing = NSEvent.isMouseCoalescingEnabled
            NSEvent.isMouseCoalescingEnabled = false
        }
        gestureSampleStart = time; gestureSamples = [GestureSample(point: point, time: 0)]
        undo.clear(); source = input; gesture.start(point, at: time); revision += 1; startAnimation(); return true
    }
    func move(_ point: Point, at time: Double, down: Bool, input: InputMode) {
        if down, gesture.active, source == input { recordSample(point, at: time); gesture.move(point, at: time); revision += 1 }
        else if !down, !gesture.active, let id = undo.move(point, at: time) {
            onUndoSelection?(id); history.removeAll { $0.id == id }; toast("Last selection undone"); revision += 1
        }
    }
    @discardableResult func end(_ point: Point, at time: Double, input: InputMode) -> Bool {
        guard gesture.active && source == input else { return false }
        recordSample(point, at: time); gesture.move(point, at: time); gesture.advance(at: time)
        let path = gesture.finish()
        recordTrace(termination: "release", path: path?.map(\.name))
        source = nil; animation?.cancel(); animation = nil
        restoreMouseCoalescing()
        if let path {
            let entry = HistoryEntry(id: nextID, path: path); nextID += 1; history.append(entry); onSelection?(entry)
            undo.arm(id: entry.id, at: time, point: point); toast("\(path.last?.name ?? "Option") selected · scribble to undo")
        }
        revision += 1; return path != nil
    }
    func cancel() {
        if gesture.active { recordTrace(termination: "cancel", path: nil) }
        restoreMouseCoalescing()
        animation?.cancel(); animation = nil; gesture.cancel(); source = nil
        revision += 1
    }
    private func restoreMouseCoalescing() {
        guard let previousMouseCoalescing else { return }
        NSEvent.isMouseCoalescingEnabled = previousMouseCoalescing
        self.previousMouseCoalescing = nil
    }
    private func recordSample(_ point: Point, at time: Double) {
        let sample = GestureSample(point: point, time: time - gestureSampleStart)
        if gestureSamples.count < 4096 { gestureSamples.append(sample) }
        else { gestureSamples[gestureSamples.count - 1] = sample }
    }
    private func recordTrace(termination: String, path: [String]?) {
        guard let source, !gestureSamples.isEmpty else { return }
        let trace = GestureTrace(date: .now, input: source.rawValue, releaseMode: gesture.mode.rawValue,
                                 termination: termination, samples: gestureSamples, selectedPath: path)
        gestureSamples = []
        Task { await gestureTraces.record(trace) }
    }
    func escape() { cancel(); undo.clear() }
    func modeChanged() { cancel(); undo.clear(); focusCanvas?() }
    func choose(_ direction: Direction) {
        let time = Self.now
        if !gesture.active { begin(Point(width / 2, height / 2), at: time - 200, input: .mouse) }
        gesture.advance(at: time)
        guard let center = centers.last else { return }
        let back = gesture.current?.incoming?.opposite == direction
        if !gesture.final || back {
            guard let option = options.first(where: { $0.direction == direction }) else { return }
            let rect = optionRect(option, center: center)
            gesture.commit(direction, isBack: back, at: time, point: Point(rect.midX, rect.midY)); revision += 1
        }
    }
    func confirmKeyboardSelection() {
        guard gesture.active else { return }
        _ = end(gesture.pointer, at: Self.now, input: source ?? .mouse)
    }
    func undoLast() { guard !history.isEmpty else { return }; cancel(); let entry = history.removeLast(); onUndoSelection?(entry.id); undo.clear(); toast("Last selection undone") }
    private func startAnimation() {
        animation?.cancel()
        animation = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.gesture.active else { break }
                if self.gesture.advance(at: Self.now) { self.revision += 1 }
                do { try await Task.sleep(for: .milliseconds(16)) } catch { break }
            }
        }
    }
    private func toast(_ text: String) {
        message = text; toastTask?.cancel()
        toastTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(1.8)) } catch { return }
            self?.message = ""
        }
    }
}
