import Foundation

actor RecipeImportPipeline {
    private let webFetcher: WebRecipeFetcher
    private let textParser: DeterministicTextRecipeParser
    private let extractionService: RecipeExtractionService
    private let imageTextExtractor: ImageTextExtractor
    private let pdfTextExtractor: PDFTextExtractor
    private let videoRecipeExtractor: VideoRecipeExtractor
    private let sourceImageFetcher: SourceImageFetcher

    init(
        webFetcher: WebRecipeFetcher = WebRecipeFetcher(),
        textParser: DeterministicTextRecipeParser = DeterministicTextRecipeParser(),
        extractionService: RecipeExtractionService = RecipeExtractionService(),
        imageTextExtractor: ImageTextExtractor = ImageTextExtractor(),
        pdfTextExtractor: PDFTextExtractor = PDFTextExtractor(),
        videoRecipeExtractor: VideoRecipeExtractor = VideoRecipeExtractor(),
        sourceImageFetcher: SourceImageFetcher = SourceImageFetcher()
    ) {
        self.webFetcher = webFetcher
        self.textParser = textParser
        self.extractionService = extractionService
        self.imageTextExtractor = imageTextExtractor
        self.pdfTextExtractor = pdfTextExtractor
        self.videoRecipeExtractor = videoRecipeExtractor
        self.sourceImageFetcher = sourceImageFetcher
    }

    func importContent(_ input: String) async throws -> RecipeDraft {
        try Task.checkCancellation()
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ImportError.noUsableContent }

        if let url = strictHTTPSURL(from: trimmed) {
            return try await importURL(url)
        }
        return try await importText(trimmed, source: .manual)
    }

    func makeManualDraft(from input: String) -> RecipeDraft {
        if let parsed = textParser.parse(input) {
            return parsed.draft
        }
        let firstLine = input
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let title = firstLine.flatMap { $0.isEmpty ? nil : $0 } ?? "Nuova ricetta"
        return RecipeDraft(
            title: title,
            summary: input,
            unresolved: [
                .init(fieldName: "ingredients", message: "Aggiungi gli ingredienti."),
                .init(fieldName: "steps", message: "Aggiungi il procedimento.")
            ],
            confidence: 0,
            extractionMethod: .manual
        )
    }

    func importImageData(_ data: Data) async throws -> RecipeDraft {
        let text = try await imageTextExtractor.extractText(from: data)
        let referenceImageURL = try? RecipeArtworkStore.makeTemporaryImage(from: data)
        let source = RecipeSourceDraft(
            title: "Immagine importata",
            author: nil,
            url: nil,
            platform: "immagine",
            attribution: nil
        )
        var draft = try await importText(text, source: source)
        draft.referenceImageURL = referenceImageURL
        return draft
    }

    func importFile(
        at url: URL,
        context: String? = nil,
        progress: @escaping @Sendable (VideoImportPhase) async -> Void = { _ in }
    ) async throws -> RecipeDraft {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        switch url.pathExtension.lowercased() {
        case "pdf":
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            let evidence = try await pdfTextExtractor.extractEvidence(from: data)
            let source = RecipeSourceDraft(
                title: url.deletingPathExtension().lastPathComponent,
                author: nil,
                url: nil,
                platform: "pdf",
                attribution: nil
            )
            var draft = try await importText(evidence.text, source: source)
            draft.referenceImageURL = evidence.referenceImageURL
            return draft
        case "jpg", "jpeg", "png", "heic", "heif", "tiff", "webp":
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            return try await importImageData(data)
        case "mov", "mp4", "m4v":
            return try await importVideo(
                at: url,
                context: context,
                progress: progress
            )
        case "txt", "md", "rtf":
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            guard let text = String(data: data, encoding: .utf8) else {
                throw ImportError.unsupportedContent
            }
            return try await importText(text, source: .manual)
        default:
            throw ImportError.unsupportedContent
        }
    }

    func importVideo(
        at url: URL,
        context: String? = nil,
        progress: @escaping @Sendable (VideoImportPhase) async -> Void = { _ in }
    ) async throws -> RecipeDraft {
        let evidence = try await videoRecipeExtractor.extractEvidence(
            from: url,
            progress: progress
        )
        await progress(.buildingEvidence)
        let source = RecipeSourceDraft(
            title: url.deletingPathExtension().lastPathComponent,
            author: nil,
            url: nil,
            platform: "video",
            attribution: nil
        )
        var draft = try await importText(
            evidence.combined(with: context),
            source: source
        )
        draft.referenceImageURL = evidence.referenceImageURL
        return draft
    }

    private func importURL(_ url: URL) async throws -> RecipeDraft {
        do {
            switch try await webFetcher.fetch(url) {
            case .structured(let recipe):
                return await attachingReferenceImage(to: recipe.draft)
            case .unstructured(let text, let source):
                if Self.isSocialURL(url), textParser.parse(text, source: source) == nil {
                    throw ImportError.socialContentUnavailable
                }
                let draft = try await importText(text, source: source)
                return await attachingReferenceImage(to: draft)
            }
        } catch {
            if Self.isSocialURL(url) {
                throw ImportError.socialContentUnavailable
            }
            throw error
        }
    }

    private func importText(
        _ text: String,
        source: RecipeSourceDraft
    ) async throws -> RecipeDraft {
        let deterministic = textParser.parse(text, source: source)
        let evidence = deterministic?.evidence ?? RecipeEvidenceBundle(
            items: [
                EvidenceItem(
                    kind: .bodyText,
                    text: String(text.prefix(30_000)),
                    confidence: 0.8,
                    provenance: .init(source: source.platform, location: "contenuto")
                )
            ],
            source: source
        )

        do {
            return try await extractionService.extractRecipe(from: evidence)
        } catch ImportError.modelUnavailable {
            if let deterministic {
                return deterministic.draft
            }
            throw ImportError.noUsableContent
        } catch {
            if let deterministic {
                return deterministic.draft
            }
            throw error
        }
    }

    private func strictHTTPSURL(from text: String) -> URL? {
        guard !text.contains(where: \.isNewline),
              let url = URL(string: text),
              url.scheme?.lowercased() == "https",
              url.host != nil
        else {
            return nil
        }
        return url
    }

    private func attachingReferenceImage(to original: RecipeDraft) async -> RecipeDraft {
        guard let imageURL = original.source.imageURL,
              let localURL = try? await sourceImageFetcher.fetchTemporaryImage(from: imageURL)
        else {
            return original
        }
        var draft = original
        draft.referenceImageURL = localURL
        return draft
    }

    private static func isSocialURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return [
            "instagram.com",
            "tiktok.com",
            "youtube.com",
            "youtu.be",
            "facebook.com"
        ].contains { host == $0 || host.hasSuffix(".\($0)") }
    }
}
