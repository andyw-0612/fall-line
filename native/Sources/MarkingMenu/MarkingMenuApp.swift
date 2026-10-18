import SwiftUI

@main struct MarkingMenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel.shared
    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.feedbackModel) private var feedbackModel
    var body: some Scene {
        Window("Fall Line", id: "main") {
            ShoppingView().frame(minWidth: 700, minHeight: 480).preferredColorScheme(.light)
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
                Picker("Drawing input", selection: Binding(
                    get: { model.inputMode },
                    set: { model.inputMode = $0; model.modeChanged() })) {
                    ForEach(InputMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
                }
                Divider()
                Button("Camera & Palm Rest Debug…") { openWindow(id: "input-debug") }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                Divider()
                SettingsLink { Text("Palm Rest Settings…") }
                Button(model.camera.isRunning ? "Disable Camera" : "Enable Palm Rest Camera", action: model.toggleCamera)
                Button("Set Up Apple Desk View", action: model.setupDeskView)
            }
            CommandGroup(after: .appInfo) {
                Button("Set Up Apple Desk View", action: (feedbackModel ?? model).setupDeskView)
            }
        }

        Window("Camera & Palm Rest Debug", id: "input-debug") {
            InputDebugView(model: model)
        }
        .defaultSize(width: 1150, height: 800)
        .windowResizability(.contentMinSize)

        Settings { InputSettingsView(model: model) }

        MenuBarExtra("Fall Line Input", systemImage: "hand.point.up.left") {
            InputSettingsView(model: model)
        }
        .menuBarExtraStyle(.window)

        Window("Marking Menu Playground", id: "playground") {
            ContentView(model: model).frame(minWidth: 700, minHeight: 480).preferredColorScheme(.light)
        }
        .defaultSize(width: 1100, height: 760)
        .windowResizability(.contentMinSize)
    }
}
