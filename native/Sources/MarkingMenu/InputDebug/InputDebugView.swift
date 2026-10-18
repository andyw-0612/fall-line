import SwiftUI

struct InputDebugView: View {
    @Bindable var model: AppModel
    @State private var showSkeleton = true
    @State private var showTrails = true
    var body: some View {
        @Bindable var camera = model.camera
        let debug = model.inputDebug
        VStack(spacing: 0) {
            HStack {
                Picker("Camera", selection: $camera.selectedID) {
                    Text("Automatic Desk View").tag("automatic")
                    ForEach(camera.choices) { choice in Text(choice.name).tag(choice.id) }
                }.frame(maxWidth: 300).disabled(camera.isBusy)
                Button(camera.isRunning || camera.isBusy ? "Stop Camera" : "Start Camera", action: model.toggleCamera)
                Button("Set Up Desk View", action: model.setupDeskView).disabled(camera.isBusy)
                Spacer()
                Button("Clear Debug", action: debug.clear)
            }.padding(16)
            Divider()
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Live camera · Google MediaPipe", systemImage: "video")
                        Spacer()
                        Toggle("Skeleton", isOn: $showSkeleton)
                        Toggle("Trails", isOn: $showTrails)
                    }.font(.callout).toggleStyle(.checkbox)
                    CameraPreview(handle: camera.pipeline.handle, tip: debug.indexTip,
                        aspect: camera.aspect, engaged: debug.isDrawing, deskView: camera.isDeskView,
                        landmarks: debug.landmarks, rawTrail: debug.rawTrail, filteredTrail: debug.filteredTrail,
                        showSkeleton: showSkeleton, showTrails: showTrails)
                        .frame(minHeight: 280)
                        .clipShape(.rect(cornerRadius: 10))
                        .overlay {
                            if !camera.isRunning {
                                VStack(spacing: 10) {
                                    Image(systemName: "video.slash").font(.largeTitle)
                                    Text(camera.isBusy ? "Starting camera…" : "Start a camera to inspect live tracking")
                                    if !camera.status.isEmpty { Text(camera.status).font(.caption) }
                                }.foregroundStyle(.white).padding(24).multilineTextAlignment(.center)
                            }
                        }
                        .accessibilityLabel("Live camera with detected hand skeleton and highlighted index fingertip")
                    Text("Green: skeleton · Orange dot: index tip · Cyan dashed: raw finger trail · Yellow: filtered trail")
                        .font(.caption).foregroundStyle(.secondary)
                    InputDebugTrailView(debug: debug).frame(height: 170)
                    Text(camera.sourceName.isEmpty ? "Camera off · no frames recorded to disk" : "\(camera.sourceName) · \(camera.status)")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }.padding(16).frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                InputDebugStatusView(model: model, debug: debug)
            }
        }
        .frame(minWidth: 1000, minHeight: 680)
        .onChange(of: camera.selectedID) { model.cameraSelectionChanged() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in model.syncTapSensor() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in model.suspendPalmInput() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.syncTapSensor() }
        .onAppear { camera.refresh(); model.syncTapSensor() }
    }
}
