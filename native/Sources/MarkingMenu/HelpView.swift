import SwiftUI

struct HelpView: View {
    @Bindable var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Marking Menu").font(.headline)
            Text("Mouse: press and follow a path to a final option, then release. Price is up, Product right, Aesthetic down, and Function left. Begin moving before the menu appears for fast gestures. Flick backward then forward to repeat a direction. Fast mode has no Back. A final choice stays selected until release. Pause for a third of a second to show the menu. In visible menus, reverse to go Back or pause to repeat a direction.")
            Text("Trackpad: keep the pointer over the canvas. Place two fingers, draw, and lift to finish. This reads finger contact directly; there is no scroll momentum.")
            LabeledContent("Trackpad sensitivity") { Slider(value: $model.trackpadSensitivity, in: 0.25...1.5).frame(width: 130) }
            Text("Finger: enable Desk View. Only your index fingertip controls the cursor. Show your hand and palm to acquire tracking; an isolated fingertip may not be detected. Pause for 200 ms then move to start. Hold a final option still for 320 ms to select. In Space mode, hold Space to draw and release to select. Brief tracking gaps hold the cursor for 450 ms and pause automatic selection. Longer gaps cancel. Escape cancels.")
            Text("Scribble within 1.5 seconds to undo. Escape cancels. Arrow keys explore; Return selects; ⌘Z undoes the last selection.")
            Text("Desk View uses Apple's native camera and setup. Compatible Mac or Continuity Camera hardware is required. Camera frames stay on this Mac.").foregroundStyle(.secondary)
        }.font(.callout)
    }
}
