import SwiftUI

struct FloatingProductCard<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date.now
    var amplitude: CGFloat = 4
    var duration: Double = 3.6
    var delay: Double = 0
    @ViewBuilder var content: Content

    var body: some View {
        // Ambient motion must not join a finite camera animation's completion
        // transaction: a repeating animation would keep that transaction open.
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startedAt) + delay
            let offset = sin(elapsed * .pi / duration) * amplitude
            content
                .background(.white, in: .rect(cornerRadius: 20))
                .compositingGroup()
                .shadow(color: .black.opacity(0.11), radius: 10, x: 2, y: 7)
                .offset(y: reduceMotion ? 0 : offset)
        }
    }
}
