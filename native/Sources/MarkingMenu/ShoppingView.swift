import SwiftUI

struct ShoppingView: View {
    @State private var session = CatalogueSession()
    @State private var isShopping = false
    @State private var showSettings = false
    var body: some View {
        Group {
            if isShopping, let product = session.currentProduct {
                ProductView(session: session, initialProduct: product, onBack: { isShopping = false })
            } else {
                StartupView(onSearch: { query in session.search(query); isShopping = true })
                    .id(session.historyResetID)
                    .disabled(!session.ready || session.loading)
                    .overlay(alignment: .bottom) {
                        VStack(spacing: 12) {
                            if session.loading { ProgressView("Finding your first shoes…") }
                            if let error = session.error {
                                Text(error).font(.callout).multilineTextAlignment(.center).frame(maxWidth: 600)
                                HStack { Button("Retry", action: session.retry); Button("Use local recommendations", action: session.useLocal) }
                            }
                            if session.exhausted { Text("No shoes match these filters. Adjust Settings and start another search.") }
                            HStack {
                                if !session.state.context.isEmpty {
                                    Button("Clear history", systemImage: "arrow.counterclockwise", action: session.clearHistory)
                                }
                                Button("Settings") { showSettings = true }
                                if session.currentProduct != nil { Button("Resume shopping") { isShopping = true } }
                                Text(session.state.mode == "ai" ? "Gemini AI" : "Local recommendations").foregroundStyle(.secondary)
                            }
                        }.padding(.bottom, 40)
                    }
            }
        }
        .onChange(of: session.currentPick?.id) { isShopping = session.currentPick != nil }
        .sheet(isPresented: $showSettings) { CataloguePanel(session: session) }
        .task { await session.load(); isShopping = session.currentProduct != nil }
    }
}
