import SwiftUI

struct InputDebugStatusView: View {
    let model: AppModel
    let debug: InputDebugState
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Tracking").font(.headline)
                Text(debug.trackingStatus)
                if let tip = debug.indexTip {
                    LabeledContent("Index · landmark 8", value: "\(tip.x.formatted(.number.precision(.fractionLength(3)))), \(tip.y.formatted(.number.precision(.fractionLength(3))))")
                } else { Text("Index fingertip not detected").foregroundStyle(.secondary) }
                LabeledContent("Capture age", value: "\(Int(debug.frameAge)) ms")
                LabeledContent("Frames processed", value: "\(debug.frames)")
                Divider()
                Text("Palm rest sensor").font(.headline)
                Text(debug.sensorStatus).font(.caption).textSelection(.enabled)
                LabeledContent("Acceleration", value: debug.acceleration.formatted(.number.precision(.fractionLength(3))) + " g")
                LabeledContent("Effective threshold", value: debug.effectiveThreshold.formatted(.number.precision(.fractionLength(3))) + " g")
                LabeledContent("Recent peak", value: debug.peak.formatted(.number.precision(.fractionLength(3))) + " g")
                LabeledContent("Sample rate", value: "\(Int(debug.sensorHz)) Hz")
                Divider()
                Text("Tap detection").font(.headline)
                LabeledContent("Detected / accepted", value: "\(debug.tapCount) / \(debug.acceptedTapCount)")
                if let time = debug.lastTapTime {
                    LabeledContent("Last tap") { Text(time, format: .dateTime.hour().minute().second()) }
                    LabeledContent("Tap strength", value: debug.lastTapMagnitude.formatted(.number.precision(.fractionLength(3))) + " g")
                }
                Text(debug.lastTapResult).font(.callout).foregroundStyle(debug.acceptedTapCount > 0 ? .green : .secondary)
                Text(debug.drawingStatus).font(.callout.bold())
                if model.inputMode != .finger {
                    Button("Use palm rest input") { model.inputMode = .finger; model.palmRestEnabled = true; model.modeChanged() }
                }
                Divider()
                Text("Recent events").font(.headline)
                if debug.events.isEmpty { Text("No input events yet.").foregroundStyle(.secondary) }
                ForEach(debug.events) { event in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.time, format: .dateTime.hour().minute().second().secondFraction(.fractional(3)))
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        Text(event.message).font(.caption).textSelection(.enabled)
                    }
                }
            }
            .font(.callout).padding(16)
        }
        .frame(width: 310)
    }
}
