import SwiftUI

struct HelpView: View {
    @Bindable var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Marking Menu").font(.headline)
            Text("Mouse: press and follow a path to a final option, then release. Price is up, Product right, Aesthetic down, and Function left. Begin moving before the menu appears for fast gestures. Flick backward then forward to repeat a direction. Fast mode has no Back. A final choice stays selected until release. Pause for a third of a second to show the menu. In visible menus, reverse to go Back or pause to repeat a direction.")
            Text("Trackpad: keep the pointer over the canvas. Place two fingers, draw, and lift to finish. This reads finger contact directly; there is no scroll momentum.")
            LabeledContent("Trackpad sensitivity") { Slider(value: $model.trackpadSensitivity, in: 0.25...1.5).frame(width: 130) }
            Text("Scribble within 1.5 seconds to undo. Escape cancels. Arrow keys explore; Return selects; ⌘Z undoes the last selection.")
        }.font(.callout)
    }
}
