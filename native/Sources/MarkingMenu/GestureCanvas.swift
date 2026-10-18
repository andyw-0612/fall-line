import SwiftUI

struct GestureCanvas: NSViewRepresentable {
    let model: AppModel
    let revision: Int
    var style: GestureCanvasStyle = .playground
    var controlBounds: [CGRect] = []
    var slowModeOverlayOpacity = 0.6
    func makeNSView(context: Context) -> GestureCanvasView { GestureCanvasView(model: model, style: style) }
    func updateNSView(_ view: GestureCanvasView, context: Context) {
        view.controlBounds = controlBounds
        view.slowModeOverlayOpacity = slowModeOverlayOpacity
        view.inputEnabled = context.environment.isEnabled
        view.needsDisplay = true
        view.refreshAccessibility()
    }
}
