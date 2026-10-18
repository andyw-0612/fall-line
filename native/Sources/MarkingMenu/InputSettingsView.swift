import SwiftUI

struct InputSettingsView: View {
    @Bindable var model: AppModel
    @State private var settings = InputSettings.load()
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Palm rest input").font(.title2.bold())
            Text("Google MediaPipe · tap the palm rest, then trace with your index finger.")
                .font(.callout).foregroundStyle(.secondary)
            CameraControls(model: model, showsPreview: false)
            Toggle("Start finger gestures with a palm rest tap", isOn: $model.palmRestEnabled)
                .onChange(of: model.palmRestEnabled) { model.modeChanged() }
            LabeledContent("Point distance", value: "\(Int(settings.pointDistance)) pt")
            Slider(value: $settings.pointDistance, in: 40...160, step: 5) { Text("Minimum distance per direction") }.labelsHidden()
            LabeledContent("Tap threshold", value: settings.tapThreshold.formatted(.number.precision(.fractionLength(3))) + " g")
            Slider(value: $settings.tapThreshold, in: 0.005...0.15, step: 0.005) { Text("Palm rest tap threshold") }.labelsHidden()
            Text("Lower threshold detects lighter taps.").font(.caption).foregroundStyle(.secondary)
            LabeledContent("Finger motion gain", value: "\(Int(settings.motionGain))")
            Slider(value: $settings.motionGain, in: 300...1800, step: 50) { Text("Finger motion gain") }.labelsHidden()
            Text(model.camera.isRunning ? model.tapStatus : "Enable a camera to use palm rest input.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Restore Defaults") { settings = InputSettings(); saved = false }
                Spacer()
                if saved { Text("Saved").foregroundStyle(.secondary) }
                Button("Save Settings") { settings.save(); saved = true }
                    .keyboardShortcut("s", modifiers: .command)
            }
        }
        .padding(24).frame(width: 470)
        .onChange(of: settings.pointDistance) { saved = false }
        .onChange(of: settings.tapThreshold) { saved = false }
        .onChange(of: settings.motionGain) { saved = false }
        .onAppear {
            settings = InputSettings.load()
            model.inputConfigurationOpen = true
            model.suspendPalmInput()
        }
        .onDisappear { model.inputConfigurationOpen = false; model.syncTapSensor() }
    }
}
