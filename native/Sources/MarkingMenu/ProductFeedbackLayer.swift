import SwiftUI

struct ProductFeedbackLayer: View {
    @AppStorage("slowModeOverlayOpacity") private var slowModeOverlayOpacity = 60.0
    @Bindable var model: AppModel
    var controlBounds: [CGRect]
    var inputEnabled = true
    @State private var confirmation: String?
    @State private var lastShownID = 0

    var body: some View {
        ZStack {
            GestureCanvas(model: model, revision: model.revision, style: .product, controlBounds: controlBounds, slowModeOverlayOpacity: slowModeOverlayOpacity / 100)

            if let confirmation {
                Text(confirmation)
                    .font(StartupStyle.headingFont(size: 28))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 28)
                    .background(.white, in: .rect(cornerRadius: 20))
                    .compositingGroup()
                    .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
                    .padding(32)
                    .transition(.opacity)
                    .allowsHitTesting(false)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .focusedSceneValue(\.feedbackModel, model)
        .disabled(!inputEnabled)
        .allowsHitTesting(inputEnabled)
        .onChange(of: inputEnabled) {
            model.inputAvailable = inputEnabled
            if !inputEnabled { model.escape(); confirmation = nil }
        }
        .onAppear {
            model.inputAvailable = inputEnabled
            model.menuPadding = 24
            model.menuScale = 0.75
            model.focusCanvas?()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            model.escape()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in model.escape() }
        .onDisappear { model.escape(); model.inputAvailable = false }
        .task(id: model.history.last?.id) {
            let text: String
            if let entry = model.history.last, entry.id > lastShownID {
                lastShownID = entry.id
                text = entry.feedbackMessage
            } else if model.message == "Last selection undone" {
                text = "Feedback undone"
            } else {
                confirmation = nil
                return
            }
            withAnimation(.easeOut(duration: 0.12)) { confirmation = text }
            do { try await Task.sleep(for: .seconds(1.15)) } catch { return }
            withAnimation(.easeOut(duration: 0.65)) { confirmation = nil }
        }
    }
}
