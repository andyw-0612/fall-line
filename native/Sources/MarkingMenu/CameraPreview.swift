import SwiftUI
import AVFoundation
import MarkingCore

struct CameraPreview: NSViewRepresentable {
    let handle: CaptureSessionHandle
    let tip: Point?
    let aspect: Double
    let engaged: Bool
    let deskView: Bool
    var landmarks: [Point] = []
    var rawTrail: [Point] = []
    var filteredTrail: [Point] = []
    var showSkeleton = true
    var showTrails = true
    func makeNSView(context: Context) -> CameraPreviewView { CameraPreviewView(handle: handle) }
    func updateNSView(_ view: CameraPreviewView, context: Context) {
        view.tip = tip; view.aspect = aspect; view.engaged = engaged; view.deskView = deskView; view.landmarks = landmarks; view.rawTrail = rawTrail; view.filteredTrail = filteredTrail
        view.showSkeleton = showSkeleton; view.showTrails = showTrails; view.needsLayout = true
    }
}
