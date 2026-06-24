import Foundation
import PDFKit
import UIKit

struct PDFRecipeEvidence: Sendable {
    let text: String
    let referenceImageURL: URL?
}

actor PDFTextExtractor {
    private let imageExtractor = ImageTextExtractor()

    func extractEvidence(
        from data: Data,
        maximumPages: Int = 20
    ) async throws -> PDFRecipeEvidence {
        guard let document = PDFDocument(data: data), document.pageCount > 0 else {
            throw ImportError.unsupportedContent
        }

        let pageCount = min(document.pageCount, maximumPages)
        var textSections: [String] = []
        var scannedPageImages: [(Int, Data)] = []
        var referenceImageURL: URL?

        for index in 0..<pageCount {
            try Task.checkCancellation()
            guard let page = document.page(at: index) else { continue }
            if index == 0 {
                let referenceImage = page.thumbnail(
                    of: CGSize(width: 1_600, height: 1_200),
                    for: .mediaBox
                )
                if let imageData = referenceImage.jpegData(compressionQuality: 0.9) {
                    referenceImageURL = try? RecipeArtworkStore.makeTemporaryImage(
                        from: imageData
                    )
                }
            }
            if let text = page.string?.trimmingCharacters(in: .whitespacesAndNewlines),
               text.count > 20 {
                textSections.append("[Pagina \(index + 1)]\n\(text)")
            } else {
                let image = page.thumbnail(
                    of: CGSize(width: 1_600, height: 2_200),
                    for: .mediaBox
                )
                if let imageData = image.jpegData(compressionQuality: 0.88) {
                    scannedPageImages.append((index, imageData))
                }
            }
        }

        for (index, imageData) in scannedPageImages {
            try Task.checkCancellation()
            if let text = try? await imageExtractor.extractText(from: imageData) {
                textSections.append("[Pagina \(index + 1), OCR]\n\(text)")
            }
        }

        let result = textSections.joined(separator: "\n\n")
        guard result.count > 20 else {
            throw ImportError.noUsableContent
        }
        return PDFRecipeEvidence(
            text: result,
            referenceImageURL: referenceImageURL
        )
    }
}
