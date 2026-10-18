import SwiftUI

struct DrawingControls: View {
    @Bindable var model: AppModel
    @State private var showHelp = false
    var body: some View {
        HStack {
            Picker("Input", selection: $model.inputMode) {
                ForEach(InputMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
            }.frame(width: 140)
            Button("Help", systemImage: "questionmark.circle") { showHelp = true }
                .popover(isPresented: $showHelp) { HelpView(model: model).padding(20).frame(width: 360) }
        }.controlSize(.small).padding(6).background(.white)
        .onChange(of: model.inputMode) { model.modeChanged() }
    }
}
