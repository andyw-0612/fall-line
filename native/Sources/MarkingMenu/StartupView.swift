import SwiftUI

struct StartupView: View {
    var onSearch: (String) -> Void = { _ in }
    @State private var query = ""

    var body: some View {
        ZStack {
            StartupStyle.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("What are you shopping for?")
                    .font(StartupStyle.headingFont(size: 48))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)

                Text("Start here. See where it leads.")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(StartupStyle.secondary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                    .padding(.top, 28)

                StartupSearchField(query: $query, onSearch: { onSearch(query) })
                    .padding(.top, 40)
            }
            .frame(maxWidth: 720)
            .padding(.horizontal, 48)
        }
        .overlay(alignment: .top) {
            FallLineWordmark()
                .padding(.top, 52)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea(.container, edges: .top)
    }
}

