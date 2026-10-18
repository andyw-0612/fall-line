import SwiftUI
import MarkingCore

struct InputDebugTrailView: View {
    let debug: InputDebugState
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Accepted drawing trail").font(.headline)
                Spacer()
                Text(debug.drawingStatus).font(.caption).foregroundStyle(.secondary)
            }
            Canvas { context, size in
                let rect = CameraDebugGeometry.videoRect(size: size, aspect: debug.screenSize.width / max(1, debug.screenSize.height))
                var path = Path()
                for (index, point) in debug.screenTrail.enumerated() {
                    let p = CGPoint(x: rect.minX + point.x / max(1, debug.screenSize.width) * rect.width,
                                    y: rect.minY + point.y / max(1, debug.screenSize.height) * rect.height)
                    if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
                }
                context.stroke(path, with: .color(.yellow), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
            .background(.black.opacity(0.85), in: .rect(cornerRadius: 8))
            .overlay {
                if debug.screenTrail.isEmpty { Text("Tap, then draw. The last trail stays here until the next stroke.").font(.caption).foregroundStyle(.white.opacity(0.6)) }
            }
            .accessibilityLabel("Accepted drawing trail, \(debug.screenTrail.count) points. \(debug.drawingStatus)")
        }
    }
}
