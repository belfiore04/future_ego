import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import Vision

// MARK: - Errors

enum SegmentationError: LocalizedError {
    case invalidImage
    case noResults
    case ciImageCreationFailed
    case renderingFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:        return "Unable to read the input image."
        case .noResults:           return "Vision did not return a mask result."
        case .ciImageCreationFailed: return "Failed to create CIImage from mask."
        case .renderingFailed:     return "Failed to render the composited image."
        }
    }
}

// MARK: - Service

struct ImageSegmentationService {
    /// Segment the foreground subject from `image` and return a new `UIImage`
    /// with a transparent background.  Uses `VNGenerateForegroundInstanceMaskRequest`
    /// (iOS 17+).
    static func segmentForeground(from image: UIImage) async throws -> UIImage {
        guard let cgImage = image.cgImage else {
            throw SegmentationError.invalidImage
        }

        // 1. Run the Vision request on a background thread.
        let maskObservation: VNInstanceMaskObservation = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let request = VNGenerateForegroundInstanceMaskRequest()
                    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                    try handler.perform([request])

                    guard let result = request.results?.first else {
                        continuation.resume(throwing: SegmentationError.noResults)
                        return
                    }
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        // 2. Generate a scaled mask pixel buffer covering all instances.
        let maskPixelBuffer = try maskObservation.generateScaledMaskForImage(
            forInstances: maskObservation.allInstances,
            from: VNImageRequestHandler(cgImage: cgImage, options: [:])
        )

        // 3. Composite the original image with the mask to produce a
        //    transparent-background result using Core Image.
        let ciContext = CIContext()

        let originalCI = CIImage(cgImage: cgImage)
        let maskCI = CIImage(cvPixelBuffer: maskPixelBuffer)

        // The mask may differ in size from the original; scale it.
        let scaleX = originalCI.extent.width / maskCI.extent.width
        let scaleY = originalCI.extent.height / maskCI.extent.height
        let scaledMask = maskCI.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        // Use CIBlendWithMask: background = transparent, input = original, mask = scaled mask.
        let filter = CIFilter.blendWithMask()
        filter.inputImage = originalCI
        filter.maskImage = scaledMask
        filter.backgroundImage = CIImage.empty()

        guard let outputCI = filter.outputImage else {
            throw SegmentationError.renderingFailed
        }

        guard let outputCG = ciContext.createCGImage(outputCI, from: originalCI.extent) else {
            throw SegmentationError.renderingFailed
        }

        return UIImage(cgImage: outputCG, scale: image.scale, orientation: image.imageOrientation)
    }
}
