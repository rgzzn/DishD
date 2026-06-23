import SwiftUI
import SwiftData

struct ImportComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var text = ""
    @State private var draft: RecipeDraft?
    @State private var isProcessing = false
    private let extractor = TextRecipeExtractor()
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Incolla testo, una caption o un URL pubblico. DishD userà ciò che la piattaforma rende disponibile, senza fallback cloud.").foregroundStyle(.secondary)
                TextEditor(text: $text).frame(minHeight: 180).padding(8).background(DishDColor.surface).clipShape(RoundedRectangle(cornerRadius: 16)).accessibilityLabel("Contenuto da importare")
                PrivacyPill()
                if isProcessing { ProgressView("Preparo la bozza") }
                if let draft { RecipeReviewView(draft: draft) { save(draft) } }
                Spacer()
            }.padding().navigationTitle("Crea ricetta").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Analizza") { Task { await analyze() } }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing) } }
        }
    }
    private func analyze() async { isProcessing = true; let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)); let sourceURL = url?.scheme?.hasPrefix("http") == true ? url : nil; draft = await extractor.extract(from: text, sourceURL: sourceURL); isProcessing = false }
    private func save(_ draft: RecipeDraft) { guard draft.isRecipe else { return }; modelContext.insert(RecipeEntityMapper.makeRecipe(from: draft)); try? modelContext.save(); dismiss() }
}
struct PrivacyPill: View { var body: some View { Label("AI locale: nessun contenuto viene inviato a modelli remoti", systemImage: "lock.shield").font(.footnote).padding(10).background(DishDColor.herb.opacity(0.14)).clipShape(Capsule()) } }
