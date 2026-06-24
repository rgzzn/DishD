import SwiftUI
import SwiftData
import Observation
import PhotosUI
import UniformTypeIdentifiers
import CoreTransferable

@MainActor
@Observable
final class ImportComposerModel {
    enum State {
        case idle
        case processing(String)
        case review(RecipeDraft)
        case failed(ImportError)
    }

    var input = ""
    var state: State = .idle
    private let pipeline: RecipeImportPipeline
    private var task: Task<Void, Never>?

    init(pipeline: RecipeImportPipeline, initialInput: String = "") {
        self.pipeline = pipeline
        self.input = initialInput
    }

    var isProcessing: Bool {
        if case .processing = state { return true }
        return false
    }

    func analyze() {
        task?.cancel()
        let currentInput = input
        state = .processing(currentInput.hasPrefix("https://") ? "Leggo la pagina" : "Riconosco ingredienti e passaggi")
        task = Task {
            do {
                let draft = try await pipeline.importContent(currentInput)
                guard !Task.isCancelled else { return }
                state = .review(draft)
            } catch is CancellationError {
                state = .idle
            } catch let error as ImportError {
                state = .failed(error)
            } catch {
                state = .failed(.extractionFailed)
            }
        }
    }

    func createManualDraft() {
        task?.cancel()
        let input = input
        Task {
            let draft = await pipeline.makeManualDraft(from: input)
            state = .review(draft)
        }
    }

    func analyzePhoto(_ item: PhotosPickerItem) {
        task?.cancel()
        state = .processing("Leggo il testo nell’immagine")
        task = Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw ImportError.unsupportedContent
                }
                let draft = try await pipeline.importImageData(data)
                guard !Task.isCancelled else { return }
                state = .review(draft)
            } catch let error as ImportError {
                state = .failed(error)
            } catch is CancellationError {
                state = .idle
            } catch {
                state = .failed(.extractionFailed)
            }
        }
    }

    func analyzeFile(_ url: URL) {
        task?.cancel()
        let context = input
        let isVideo = ["mov", "mp4", "m4v"].contains(url.pathExtension.lowercased())
        state = .processing(
            isVideo
                ? VideoImportPhase.preparing.italianLabel
                : url.pathExtension.lowercased() == "pdf"
                    ? "Leggo il documento"
                    : "Leggo il file"
        )
        task = Task {
            do {
                let draft = try await pipeline.importFile(
                    at: url,
                    context: context,
                    progress: { phase in
                        await self.updateVideoPhase(phase)
                    }
                )
                guard !Task.isCancelled else { return }
                state = .review(draft)
            } catch let error as ImportError {
                state = .failed(error)
            } catch is CancellationError {
                state = .idle
            } catch {
                state = .failed(.extractionFailed)
            }
        }
    }

    func analyzeVideo(_ item: PhotosPickerItem) {
        task?.cancel()
        let context = input
        state = .processing(VideoImportPhase.preparing.italianLabel)
        task = Task {
            do {
                guard let video = try await item.loadTransferable(type: ImportedVideo.self) else {
                    throw ImportError.unsupportedContent
                }
                defer { try? FileManager.default.removeItem(at: video.url) }
                let draft = try await pipeline.importVideo(
                    at: video.url,
                    context: context,
                    progress: { phase in
                        await self.updateVideoPhase(phase)
                    }
                )
                guard !Task.isCancelled else { return }
                state = .review(draft)
            } catch let error as ImportError {
                state = .failed(error)
            } catch is CancellationError {
                state = .idle
            } catch {
                state = .failed(.extractionFailed)
            }
        }
    }

    private func updateVideoPhase(_ phase: VideoImportPhase) {
        guard isProcessing else { return }
        state = .processing(phase.italianLabel)
    }

    func reset() {
        task?.cancel()
        state = .idle
    }

    func cancel() {
        task?.cancel()
    }
}

struct ImportComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var model: ImportComposerModel
    @State private var saveError: String?
    @State private var didAutomaticallyAnalyze = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedVideo: PhotosPickerItem?
    @State private var showingFileImporter = false
    private let automaticallyAnalyze: Bool
    private let initialFileURL: URL?

    init(
        pipeline: RecipeImportPipeline,
        initialInput: String? = nil,
        initialFileURL: URL? = nil,
        automaticallyAnalyze: Bool = false
    ) {
        _model = State(
            initialValue: ImportComposerModel(
                pipeline: pipeline,
                initialInput: initialInput ?? ""
            )
        )
        self.initialFileURL = initialFileURL
        self.automaticallyAnalyze = automaticallyAnalyze
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    inputEditor
                    sourceButtons
                    PrivacyPill()
                    stateContent
                }
                .padding()
            }
            .background(DishDColor.canvas.ignoresSafeArea())
            .navigationTitle("Crea ricetta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        model.cancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Analizza", systemImage: "sparkles") {
                        model.analyze()
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isProcessing)
                }
            }
            .alert("Salvataggio non riuscito", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
            .task {
                guard !didAutomaticallyAnalyze else { return }
                didAutomaticallyAnalyze = true
                if let initialFileURL {
                    model.analyzeFile(initialFileURL)
                } else if automaticallyAnalyze {
                    model.analyze()
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                model.analyzePhoto(item)
            }
            .onChange(of: selectedVideo) { _, item in
                guard let item else { return }
                model.analyzeVideo(item)
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.pdf, .plainText, .text, .movie],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    model.analyzeFile(url)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Da contenuto caotico a ricetta ordinata")
                .font(.largeTitle.bold())
                .foregroundStyle(DishDColor.ink)
            Text("Incolla testo, una didascalia o un URL pubblico. Per i link DishD legge prima i dati ricetta della pagina; usa Apple Intelligence locale solo quando serve.")
                .foregroundStyle(DishDColor.secondaryInk)
        }
    }

    private var inputEditor: some View {
        TextEditor(text: $model.input)
            .font(.body)
            .frame(minHeight: 190)
            .padding(12)
            .scrollContentBackground(.hidden)
            .background(DishDColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: DishDRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DishDRadius.card, style: .continuous)
                    .stroke(DishDColor.herb.opacity(0.22), lineWidth: 1)
            }
            .accessibilityLabel("Contenuto da importare")
    }

    private var sourceButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Foto", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)

                PhotosPicker(selection: $selectedVideo, matching: .videos) {
                    Label("Video", systemImage: "video")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }

            Button {
                showingFileImporter = true
            } label: {
                Label("PDF, testo o video da File", systemImage: "doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        switch model.state {
        case .idle:
            ImportHintCard()
        case .processing(let phase):
            ImportProgressView(phase: phase) {
                model.cancel()
                model.reset()
            }
        case .review(let draft):
            RecipeReviewView(draft: draft) { updatedDraft in
                save(updatedDraft)
            } onRestart: {
                model.reset()
            }
        case .failed(let error):
            ErrorRecoveryView(
                title: error.errorDescription ?? "Importazione non riuscita",
                message: error.recoverySuggestion ?? "Puoi riprovare o continuare manualmente.",
                retryAction: model.analyze,
                manualAction: model.createManualDraft
            )
        }
    }

    private func save(_ draft: RecipeDraft) {
        guard draft.isRecipe else { return }
        do {
            let recipe = RecipeEntityMapper.makeRecipe(from: draft)
            if let generatedImageURL = draft.generatedImageURL {
                recipe.heroImageRelativePath = try RecipeArtworkStore.persistGeneratedImage(
                    from: generatedImageURL,
                    recipeID: recipe.id
                )
            } else if let referenceImageURL = draft.referenceImageURL {
                recipe.heroImageRelativePath = try RecipeArtworkStore.persistGeneratedImage(
                    from: referenceImageURL,
                    recipeID: recipe.id
                )
            }
            modelContext.insert(recipe)
            try modelContext.save()
            dismiss()
        } catch {
            saveError = "La ricetta non è stata salvata. Controlla lo spazio disponibile e riprova."
        }
    }
}

struct PrivacyPill: View {
    var body: some View {
        Label(
            "AI locale: nessun contenuto viene inviato a modelli remoti",
            systemImage: "lock.shield"
        )
        .font(.footnote)
        .foregroundStyle(DishDColor.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(DishDColor.herb.opacity(0.14), in: Capsule())
        .accessibilityLabel("Privacy. L’intelligenza artificiale lavora sul dispositivo.")
    }
}

private struct ImportHintCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Funziona meglio con", systemImage: "lightbulb")
                .font(.headline)
            Text("Pagine con dati Recipe, elenchi di ingredienti, procedimenti numerati e didascalie complete.")
                .foregroundStyle(.secondary)
            Text("Se un social condivide soltanto il link, aggiungi anche didascalia o testo.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Label(
                "Da Instagram e TikTok condividi il link pubblico del video: DishD legge caption e metadati disponibili.",
                systemImage: "link.badge.plus"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .dishdCard()
    }
}

private struct ImportedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let destination = FileManager.default.temporaryDirectory
                .appending(path: "\(UUID().uuidString).\(received.file.pathExtension.nilIfBlank ?? "mov")")
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: received.file, to: destination)
            return ImportedVideo(url: destination)
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

struct ImportProgressView: View {
    let phase: String
    let cancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(phase)
                .font(.headline)
            Text("L’elaborazione resta sul dispositivo, salvo il download della pagina che hai scelto.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Annulla", role: .cancel, action: cancel)
                .buttonStyle(.glass)
        }
        .frame(maxWidth: .infinity)
        .dishdCard()
    }
}

struct ErrorRecoveryView: View {
    let title: String
    let message: String
    let retryAction: () -> Void
    let manualAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: "exclamationmark.triangle")
                .font(.title3.bold())
                .foregroundStyle(.orange)
            Text(message)
                .foregroundStyle(.secondary)
            HStack {
                Button("Riprova", action: retryAction)
                    .buttonStyle(.glass)
                Button("Importa comunque", action: manualAction)
                    .buttonStyle(.glassProminent)
            }
        }
        .dishdCard()
    }
}
