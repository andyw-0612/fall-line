import Foundation

public enum FingertipDecoder {
    /// YOLOv5 rows: center x/y, width/height in input pixels, objectness, two class scores.
    /// Both trained labels (fingertip/fingertipdetection) describe the same target.
    public static func decode(rows: Int, inputSize: Double = 416, read: (Int, Int) -> Double) -> [FingertipDetection] {
        var candidates: [FingertipDetection] = []
        for row in 0..<rows {
            let objectness = read(row, 4)
            guard objectness.isFinite, objectness >= 0.4 else { continue }
            let confidence = objectness * max(read(row, 5), read(row, 6))
            guard confidence.isFinite, confidence >= 0.4, confidence <= 1 else { continue }
            let x = read(row, 0) / inputSize, y = read(row, 1) / inputSize
            let width = read(row, 2) / inputSize, height = read(row, 3) / inputSize
            guard [x, y, width, height].allSatisfy(\.isFinite), width > 0, height > 0 else { continue }
            let bounds = CGRect(x: x - width / 2, y: y - height / 2, width: width, height: height)
                .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
            guard !bounds.isNull, bounds.width > 0, bounds.height > 0 else { continue }
            candidates.append(FingertipDetection(bounds: bounds, confidence: confidence))
        }
        var kept: [FingertipDetection] = []
        for candidate in candidates.sorted(by: { $0.confidence > $1.confidence }) {
            let overlaps = kept.contains { other in
                let intersection = candidate.bounds.intersection(other.bounds)
                let area = intersection.isNull ? 0 : intersection.width * intersection.height
                let union = candidate.bounds.width * candidate.bounds.height + other.bounds.width * other.bounds.height - area
                return union > 0 && area / union > 0.45
            }
            if !overlaps { kept.append(candidate) }
            if kept.count == 20 { break }
        }
        return kept
    }
}
