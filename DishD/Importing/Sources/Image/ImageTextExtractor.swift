import Foundation
import ImageIO
import Vision

actor ImageTextExtractor {
    func extractText(from data: Data) throws -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw ImportError.unsupportedContent
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["it-IT", "en-US"]

        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])

        let lines = request.results?
            .compactMap { $0.topCandidates(1).first?.string }
            ?? []
        let text = lines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 8 else {
            throw ImportError.noUsableContent
        }
        return text
    }
}
