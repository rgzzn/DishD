import Foundation

@main
struct ArtworkStoreVerifier {
    static func main() throws {
        let fixture = URL(fileURLWithPath: "/tmp/dishd-ingredients-v2.png")
        guard FileManager.default.fileExists(atPath: fixture.path) else {
            print("Artwork fixture skipped: \(fixture.path) missing")
            return
        }

        let temporary = try RecipeArtworkStore.copyToTemporaryStorage(from: fixture)
        guard FileManager.default.fileExists(atPath: temporary.path) else {
            throw ArtworkVerificationFailure.temporaryCopy
        }

        let recipeID = UUID()
        let relativePath = try RecipeArtworkStore.persistGeneratedImage(
            from: temporary,
            recipeID: recipeID
        )
        guard let persisted = RecipeArtworkStore.persistentURL(for: relativePath) else {
            throw ArtworkVerificationFailure.persistentCopy
        }

        try FileManager.default.removeItem(at: persisted)
        try? FileManager.default.removeItem(at: temporary)
        print("DishD artwork storage verification passed")
    }
}

private enum ArtworkVerificationFailure: Error {
    case temporaryCopy
    case persistentCopy
}
