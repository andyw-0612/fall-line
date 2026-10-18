import SwiftUI
import MarkingCore

struct CameraControls: View {
    @Bindable var model: AppModel
    var showsPreview = true
    @State private var helpVisible = false
    var body: some View {
        @Bindable var camera = model.camera
        VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 8) {
                Picker("Input", selection: $model.inputMode) {
                    ForEach(InputMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
                }.labelsHidden().frame(width: 100).help("Choose mouse, actual two-finger trackpad contact, or camera finger input")
                Button(model.camera.isRunning || model.camera.isBusy ? "Disable Camera" : "Enable Desk View", action: model.toggleCamera)
                Button("Set up Desk View", action: model.setupDeskView).disabled(model.camera.isBusy)
                Button("Help", systemImage: "questionmark.circle", action: showHelp).labelStyle(.iconOnly)
                    .popover(isPresented: $helpVisible) { HelpView(model: model).padding(20).frame(width: 360) }
            }
            if model.inputMode == .finger || model.camera.isRunning {
                HStack(spacing: 8) {
                    Picker("Camera", selection: $camera.selectedID) {
                        Text("Automatic Desk View").tag("automatic")
                        ForEach(model.camera.choices) { camera in Text(camera.name).tag(camera.id) }
                    }.labelsHidden().frame(maxWidth: 210).disabled(model.camera.isBusy)
                    if !model.palmRestEnabled { Picker("Finger activation", selection: $model.clutchMode) {
                        ForEach(HandClutch.Mode.allCases, id: \.self) { mode in Text(mode.rawValue).tag(mode) }
                    }.labelsHidden().frame(width: 130) }
                }
            }
            if !model.camera.status.isEmpty { Text(model.camera.status).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.trailing).frame(maxWidth: 360) }
            if model.camera.isRunning {
                Text("Google MediaPipe · index fingertip").font(.caption).foregroundStyle(.secondary)
                Text((model.camera.isDeskView ? "Apple Desk View · " : "Camera · ") + model.camera.sourceName).font(.caption).foregroundStyle(.secondary)
                if showsPreview { Toggle("Preview", isOn: $model.previewVisible).toggleStyle(.checkbox) }
                if showsPreview && model.previewVisible {
                    CameraPreview(handle: model.camera.pipeline.handle, tip: model.camera.previewTip, aspect: model.camera.aspect, engaged: (model.clutch.down || model.palm.state == .drawing), deskView: model.camera.isDeskView)
                        .frame(width: 180, height: 135).border(.gray.opacity(0.3))
                        .accessibilityLabel("Live camera preview with index-finger cursor. \((model.clutch.down || model.palm.state == .drawing) ? "Pen down" : "Pen up")")
                }
            }
        }
        .controlSize(.small).padding(6).background(.white)
        .onChange(of: model.inputMode) { model.modeChanged() }
        .onChange(of: model.clutchMode) { model.clutchChanged() }
        .onChange(of: model.camera.selectedID) { model.cameraSelectionChanged() }
    }
    private func showHelp() { helpVisible = true; model.camera.refresh() }
}
