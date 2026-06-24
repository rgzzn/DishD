import Foundation

@main
struct VideoEvidenceVerifier {
    static func main() async throws {
        let url = URL(fileURLWithPath: "/tmp/dishd-recipe-video.mp4")
        let evidence = try await VideoRecipeExtractor().extractEvidence(from: url) { phase in
            print(phase.italianLabel)
        }
        let text = evidence.frameText?.lowercased() ?? ""
        print(evidence.frameText ?? "Nessun testo OCR")
        if text.contains("spaghetti"),
           text.contains("parmigiano"),
           text.contains("procedimento"),
           evidence.referenceImageURL.map({
               FileManager.default.fileExists(atPath: $0.path)
           }) == true {
            print("DishD video OCR verification passed")
        } else {
            print("DishD video OCR verification failed")
        }
        let parsed = DeterministicTextRecipeParser().parse(evidence.combined(with: nil))?.draft
        print("Titolo: \(parsed?.title ?? "nil")")
        print("Ingredienti: \(parsed?.ingredients.map(\.originalText) ?? [])")
        print("Passaggi: \(parsed?.steps.map(\.instruction) ?? [])")
        if parsed?.title == "PASTA AL LIMONE",
           parsed?.ingredients.count == 5,
           parsed?.steps.count == 3 {
            print("DishD video recipe verification passed")
        } else {
            print("DishD video recipe verification failed")
        }
    }
}
