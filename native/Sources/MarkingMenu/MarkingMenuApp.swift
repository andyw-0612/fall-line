import SwiftUI

@main struct MarkingMenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel.shared
    @FocusedValue(\.feedbackModel) private var feedbackModel
    var body: some Scene {
        Window("Fall Line", id: "main") {
            ShoppingView().frame(minWidth: 700, minHeight: 480).preferredColorScheme(.light)
                .onChange(of: model.inputMode) { model.modeChanged() }
        }
        .defaultSize(width: 1272, height: 904)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .undoRedo) {
                Button("Undo Last Selection", action: (feedbackModel ?? model).undoLast).keyboardShortcut("z").disabled((feedbackModel ?? model).history.isEmpty)
            }
            CommandMenu("Input") {
                Picker("Drawing input", selection: $model.inputMode) {
                    ForEach(InputMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
                }
            }
        }


        Window("Marking Menu Playground", id: "playground") {
            ContentView(model: model).frame(minWidth: 700, minHeight: 480).preferredColorScheme(.light)
        }
        .defaultSize(width: 1100, height: 760)
        .windowResizability(.contentMinSize)
    }
}
