import ImageIO
import UIKit
import Vision

enum OCRError: LocalizedError {
    case missingImageData
    case noText

    var errorDescription: String? {
        switch self {
        case .missingImageData:
            return "The selected image could not be read."
        case .noText:
            return "No readable text was found."
        }
    }
}

final class OCRService {
    func recognizeText(in image: UIImage) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let cgImage = image.cgImage else {
                    continuation.resume(throwing: OCRError.missingImageData)
                    return
                }

                let request = VNRecognizeTextRequest { request, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    let observations = request.results as? [VNRecognizedTextObservation] ?? []
                    let lines = observations.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }

                    if lines.isEmpty {
                        continuation.resume(throwing: OCRError.noText)
                    } else {
                        continuation.resume(returning: lines)
                    }
                }

                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false

                let preferredLanguages = ["zh-Hans", "zh-Hant", "en-US"]
                let supportedLanguages = (try? request.supportedRecognitionLanguages()) ?? preferredLanguages
                let availableLanguages = preferredLanguages.filter { supportedLanguages.contains($0) }
                request.recognitionLanguages = availableLanguages.isEmpty ? supportedLanguages : availableLanguages

                let handler = VNImageRequestHandler(
                    cgImage: cgImage,
                    orientation: image.cgImageOrientation,
                    options: [:]
                )

                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

private extension UIImage {
    var cgImageOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up:
            return .up
        case .upMirrored:
            return .upMirrored
        case .down:
            return .down
        case .downMirrored:
            return .downMirrored
        case .left:
            return .left
        case .leftMirrored:
            return .leftMirrored
        case .right:
            return .right
        case .rightMirrored:
            return .rightMirrored
        @unknown default:
            return .up
        }
    }
}
