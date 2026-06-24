import Foundation

actor SourceImageFetcher {
    private let validator = SafeURLValidator()
    private let maximumBytes = 12_000_000

    func fetchTemporaryImage(from rawURL: URL) async throws -> URL {
        let url = try validator.validate(rawURL)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 25
        configuration.httpAdditionalHeaders = [
            "Accept": "image/avif,image/webp,image/*",
            "User-Agent": "DishD/1.0 (recipe artwork reference)"
        ]
        let session = URLSession(configuration: configuration)
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let finalURL = http.url
        else {
            throw ImportError.inaccessibleURL
        }
        _ = try validator.validate(finalURL)
        guard data.count <= maximumBytes else {
            throw ImportError.responseTooLarge
        }
        guard http.mimeType?.lowercased().hasPrefix("image/") == true else {
            throw ImportError.unsupportedContent
        }
        return try RecipeArtworkStore.makeTemporaryImage(from: data)
    }
}
