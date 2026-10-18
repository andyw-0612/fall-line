import SwiftUI

struct FallLineWordmark: View {
    var body: some View {
        HStack(spacing: 8) {
            Canvas { context, size in
                let slope = Path { path in
                    path.move(to: .zero)
                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    path.addLine(to: CGPoint(x: 0, y: size.height))
                    path.closeSubpath()
                }
                context.fill(slope, with: .color(.black))
                context.fill(
                    Path(ellipseIn: CGRect(x: 10, y: 6, width: 8, height: 8)),
                    with: .color(.black)
                )
            }
            .frame(width: 18, height: 30)
            Text("Fall Line")
                .font(.system(size: 34, weight: .regular))
                .tracking(-1.4)
        }
        .foregroundStyle(.black)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fall Line")
    }
}
