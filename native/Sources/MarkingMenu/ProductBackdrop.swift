import SwiftUI

struct ProductBackdrop: View {
    var body: some View {
        StartupStyle.background
            .overlay {
                Canvas { context, size in
                    for x in stride(from: 37.0, to: size.width, by: 40) {
                        for y in stride(from: 5.0, to: size.height, by: 40) {
                            context.fill(
                                Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)),
                                with: .color(.white.opacity(0.48))
                            )
                        }
                    }
                }
                .accessibilityHidden(true)
            }
    }
}
