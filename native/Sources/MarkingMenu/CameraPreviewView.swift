import AppKit
import AVFoundation
import MarkingCore

@MainActor final class CameraPreviewView: NSView {
    private let preview = AVCaptureVideoPreviewLayer()
    private let marker = CAShapeLayer()
    private let skeleton = CAShapeLayer()
    private let joints = CAShapeLayer()
    private let rawPath = CAShapeLayer()
    private let filteredPath = CAShapeLayer()
    var landmarks: [Point] = []
    var rawTrail: [Point] = []
    var filteredTrail: [Point] = []
    var showSkeleton = true
    var showTrails = true
    var tip: Point?
    var aspect = 4.0 / 3
    var engaged = false
    var deskView = false
    override var isFlipped: Bool { true }
    init(handle: CaptureSessionHandle) {
        super.init(frame: .zero); wantsLayer = true
        preview.session = handle.session; preview.videoGravity = .resizeAspect
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.black.cgColor
        for child in [preview, rawPath, filteredPath, skeleton, joints, marker] { layer?.addSublayer(child) }
        skeleton.strokeColor = NSColor.systemGreen.cgColor; skeleton.fillColor = nil; skeleton.lineWidth = 2
        joints.fillColor = NSColor.systemGreen.cgColor
        rawPath.strokeColor = NSColor.systemCyan.cgColor; rawPath.fillColor = nil; rawPath.lineWidth = 2; rawPath.lineDashPattern = [5, 4]
        filteredPath.strokeColor = NSColor.systemYellow.cgColor; filteredPath.fillColor = nil; filteredPath.lineWidth = 3
        marker.lineWidth = 2
    }
    required init?(coder: NSCoder) { nil }
    private func trailPath(_ points: [Point], rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        for (index, point) in points.enumerated() {
            let p = CameraDebugGeometry.project(point, into: rect, deskView: deskView)
            if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        return path
    }
    override func layout() {
        super.layout(); CATransaction.begin(); CATransaction.setDisableActions(true)
        preview.frame = bounds
        if let connection = preview.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false; connection.isVideoMirrored = false
        }
        // Mirror only the video layer; marker coordinates use the same explicit
        // transform as the gesture cursor, independent of AVFoundation defaults.
        preview.setAffineTransform(deskView ? .identity : CGAffineTransform(scaleX: -1, y: 1))
        let imageRect = CameraDebugGeometry.videoRect(size: bounds.size, aspect: aspect)
        let bones = CGMutablePath(), dots = CGMutablePath()
        if showSkeleton, landmarks.count == 21 {
            for (a, b) in CameraDebugGeometry.connections {
                bones.move(to: CameraDebugGeometry.project(landmarks[a], into: imageRect, deskView: deskView))
                bones.addLine(to: CameraDebugGeometry.project(landmarks[b], into: imageRect, deskView: deskView))
            }
            for point in landmarks {
                let p = CameraDebugGeometry.project(point, into: imageRect, deskView: deskView)
                dots.addEllipse(in: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6))
            }
        }
        skeleton.path = bones; joints.path = dots
        rawPath.path = trailPath(showTrails ? rawTrail : [], rect: imageRect)
        filteredPath.path = trailPath(showTrails ? filteredTrail : [], rect: imageRect)
        if let tip {
            let tip = HandPose.interactionPoint(tip, deskView: deskView)
            let width = min(bounds.width, bounds.height * aspect), height = width / aspect
            let center = CGPoint(x: (bounds.width - width) / 2 + tip.x * width,
                                 y: (bounds.height - height) / 2 + tip.y * height)
            marker.path = CGPath(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8), transform: nil)
            marker.fillColor = (!landmarks.isEmpty ? NSColor.systemOrange : engaged ? NSColor.black : NSColor.white).cgColor
            marker.strokeColor = (engaged ? NSColor.white : NSColor.black).cgColor
        } else { marker.path = nil }
        CATransaction.commit()
    }
}
