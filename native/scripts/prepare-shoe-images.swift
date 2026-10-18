import AppKit
import CoreImage
import CryptoKit
import ImageIO
import UniformTypeIdentifiers
import Vision

// Non-generative foreground extraction: preserve the source photo's dimensions
// and colors, replacing only the masked background with opaque sRGB white.
let arguments = CommandLine.arguments
if arguments.count < 3 {
    fputs("Usage: prepare-shoe-images <catalogue-root> <output-directory> [limit]\n", stderr)
    exit(1)
}
let sourceRoot = URL(fileURLWithPath: arguments[1])
let destination = URL(fileURLWithPath: arguments[2])
let limit = arguments.count > 3 ? Int(arguments[3]) ?? 450 : 450
let data = try Data(contentsOf: sourceRoot.appendingPathComponent("data/enriched-450/catalogue.json"))
struct Catalogue: Decodable {
    struct Product: Decodable { let id: String; let title: String; let image_path: String }
    let products: [Product]
}
let products = try JSONDecoder().decode(Catalogue.self, from: data).products
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
let context = CIContext(options: [.cacheIntermediates: false])
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let cacheURL = destination.appendingPathComponent("source-hashes.json")
var sourceHashes = (try? JSONDecoder().decode([String: String].self, from: Data(contentsOf: cacheURL))) ?? [:]
var completed = 0
var failures: [[String: String]] = []
for product in products.prefix(limit) {
    let output = destination.appendingPathComponent(product.id + ".png")
    let input = sourceRoot.appendingPathComponent("data/enriched-450").appendingPathComponent(product.image_path).standardizedFileURL
    let sourceHash = try SHA256.hash(data: Data(contentsOf: input)).map { String(format: "%02x", $0) }.joined()
    if FileManager.default.fileExists(atPath: output.path), sourceHashes[product.id] == sourceHash { completed += 1; continue }
    do {
        try autoreleasepool {
            guard let source = CGImageSourceCreateWithURL(input as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw NSError(domain: "ShoeImage", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot decode source"])
            }
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])
            guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
                throw NSError(domain: "ShoeImage", code: 2, userInfo: [NSLocalizedDescriptionKey: "No foreground detected"])
            }
            let buffer = try observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler)
            let foreground = CIImage(cgImage: image)
            let mask = CIImage(cvPixelBuffer: buffer)
            let white = CIImage(color: .white).cropped(to: foreground.extent)
            let result = foreground.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: white, kCIInputMaskImageKey: mask])
            try context.writePNGRepresentation(of: result, to: output, format: .RGBA8, colorSpace: colorSpace)
        }
        sourceHashes[product.id] = sourceHash
        try JSONEncoder().encode(sourceHashes).write(to: cacheURL, options: .atomic)
        completed += 1
        if completed.isMultiple(of: 10) || completed == limit { print("Prepared \(completed)/\(limit)"); fflush(stdout) }
    } catch {
        failures.append(["id": product.id, "title": product.title, "error": error.localizedDescription])
        print("Needs review: \(product.id): \(error.localizedDescription)"); fflush(stdout)
    }
}
let report: [String: Any] = ["prepared": completed, "requested": min(limit, products.count), "failures": failures, "method": "Apple Vision foreground instance mask over sRGB white"]
try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: destination.appendingPathComponent("report.json"), options: .atomic)
print("Finished: \(completed) prepared; \(failures.count) need review.")
if !failures.isEmpty { exit(2) }
