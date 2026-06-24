import ImagePlayground
import SwiftUI
import UIKit

struct RecipeArtworkEditor: View {
    @Binding var draft: RecipeDraft
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @State private var isPresentingPlayground = false
    @State private var didAutomaticallyOfferGeneration = false
    @State private var errorMessage: String?

    private var previewURL: URL? {
        draft.generatedImageURL ?? draft.referenceImageURL
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Copertina del piatto")
                        .font(.title2.bold())
                    Text(draft.generatedImageURL == nil
                         ? "DishD prepara nome, ingredienti e immagine della fonte per Image Playground."
                         : "Copertina generata con i dati della ricetta.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "photo.badge.sparkles")
                    .font(.title2)
                    .foregroundStyle(DishDColor.blueberry)
            }

            LocalRecipeArtworkView(
                url: previewURL,
                placeholderSymbol: draft.referenceImageURL == nil
                    ? "fork.knife"
                    : "photo.badge.sparkles"
            )
            .frame(height: 190)
            .overlay(alignment: .bottomLeading) {
                if draft.generatedImageURL == nil, draft.referenceImageURL != nil {
                    Label("Immagine sorgente", systemImage: "photo")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(12)
                }
            }

            if supportsImagePlayground {
                Button {
                    isPresentingPlayground = true
                } label: {
                    Label(
                        draft.generatedImageURL == nil
                            ? "Genera copertina con AI"
                            : "Rigenera copertina",
                        systemImage: "sparkles"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
            } else {
                Label(
                    "Image Playground non è disponibile su questo dispositivo.",
                    systemImage: "iphone.slash"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .modifier(
            RecipeImagePlaygroundSheet(
                isPresented: $isPresentingPlayground,
                concepts: RecipeArtworkPromptBuilder.concepts(for: draft),
                sourceImageURL: draft.referenceImageURL,
                onCompletion: acceptGeneratedImage
            )
        )
        .task {
            guard supportsImagePlayground,
                  !didAutomaticallyOfferGeneration,
                  draft.generatedImageURL == nil
            else {
                return
            }
            didAutomaticallyOfferGeneration = true
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            isPresentingPlayground = true
        }
    }

    private func acceptGeneratedImage(_ url: URL) {
        do {
            draft.generatedImageURL = try RecipeArtworkStore.copyToTemporaryStorage(from: url)
            errorMessage = nil
        } catch {
            errorMessage = "L’immagine è stata creata, ma non è stato possibile prepararla per il salvataggio."
        }
    }
}

struct LocalRecipeArtworkView: View {
    let url: URL?
    var placeholderSymbol = "fork.knife"

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    DishDColor.herb.opacity(0.24),
                    DishDColor.saffron.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let url, let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: placeholderSymbol)
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(DishDColor.herbStrong)
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityLabel(url == nil ? "Copertina non ancora generata" : "Copertina della ricetta")
    }
}

private struct RecipeImagePlaygroundSheet: ViewModifier {
    @Binding var isPresented: Bool
    let concepts: [ImagePlaygroundConcept]
    let sourceImageURL: URL?
    let onCompletion: (URL) -> Void

    func body(content: Content) -> some View {
        Group {
            if let sourceImageURL {
                content.imagePlaygroundSheet(
                    isPresented: $isPresented,
                    concepts: concepts,
                    sourceImageURL: sourceImageURL,
                    onCompletion: onCompletion
                )
            } else {
                content.imagePlaygroundSheet(
                    isPresented: $isPresented,
                    concepts: concepts,
                    sourceImage: nil,
                    onCompletion: onCompletion
                )
            }
        }
        .imagePlaygroundGenerationStyle(
            .illustration,
            in: [.illustration, .animation, .sketch]
        )
        .imagePlaygroundOptions(options)
    }

    private var options: ImagePlaygroundOptions {
        var options = ImagePlaygroundOptions()
        options.creationStrategy = sourceImageURL == nil ? .generateNew : .automatic
        options.creationVariety = .low
        options.personalization = .disabled
        options.sizeSpecification = .closest(to: CGSize(width: 1_200, height: 800))
        return options
    }
}
