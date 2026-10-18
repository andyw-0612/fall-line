import SwiftUI

struct ContentView: View {
    @Bindable var model: AppModel
    var body: some View {
        ZStack(alignment: .topLeading) {
            GestureCanvas(model: model, revision: model.revision)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(model.history) { entry in Text(entry.title).font(.callout).foregroundStyle(.black) }
            }
            .padding(20).allowsHitTesting(false).accessibilityElement(children: .contain).accessibilityLabel("Selection history")
        }
        .overlay(alignment: .topTrailing) { CameraControls(model: model).padding(14) }
        .overlay(alignment: .bottomLeading) {
            if !model.message.isEmpty { Text(model.message).font(.callout).foregroundStyle(.secondary).padding(20).allowsHitTesting(false).accessibilityAddTraits(.updatesFrequently) }
        }
        .background(.white)
    }
}
