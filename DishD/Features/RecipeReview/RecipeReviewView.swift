import SwiftUI

struct RecipeReviewView: View {
    @State private var draft: RecipeDraft
    let onSave: (RecipeDraft) -> Void
    let onRestart: () -> Void

    init(
        draft: RecipeDraft,
        onSave: @escaping (RecipeDraft) -> Void,
        onRestart: @escaping () -> Void
    ) {
        _draft = State(initialValue: draft)
        self.onSave = onSave
        self.onRestart = onRestart
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                ConfidenceBadge(draft: draft)
                Spacer()
                Label(draft.extractionMethod.italianLabel, systemImage: "iphone")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !draft.isRecipe {
                ErrorRecoveryView(
                    title: "Contenuto non riconosciuto come ricetta",
                    message: "Puoi correggere la bozza manualmente oppure modificare il contenuto di partenza.",
                    retryAction: onRestart,
                    manualAction: { draft.isRecipe = true }
                )
            }

            TextField("Titolo", text: $draft.title, axis: .vertical)
                .font(.title.bold())
                .textFieldStyle(.plain)

            RecipeArtworkEditor(draft: $draft)
            metadataFields
            ingredientEditor
            stepEditor

            if !draft.unresolved.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Da controllare")
                        .font(.headline)
                    ForEach(draft.unresolved) { issue in
                        ReviewIssueCard(issue: issue)
                    }
                }
            }

            HStack {
                Button("Ricomincia", role: .cancel, action: onRestart)
                    .buttonStyle(.glass)
                Spacer()
                Button("Salva ricetta") {
                    onSave(draft)
                }
                .buttonStyle(.glassProminent)
                .disabled(draft.title.trimmingCharacters(in: .whitespaces).isEmpty || (draft.ingredients.isEmpty && draft.steps.isEmpty))
            }
        }
        .dishdCard()
    }

    private var metadataFields: some View {
        HStack {
            TextField(
                "Porzioni",
                text: Binding(
                    get: { draft.servingsLabel ?? draft.servings?.description ?? "" },
                    set: {
                        draft.servingsLabel = $0
                        draft.servings = DecimalParser.parse($0)
                    }
                )
            )
            .keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)

            if let total = draft.totalTimeSeconds {
                Label(total.formattedDuration, systemImage: "clock")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var ingredientEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ingredienti")
                    .font(.title2.bold())
                Spacer()
                Button("Aggiungi", systemImage: "plus") {
                    if draft.ingredientSections.isEmpty {
                        draft.ingredientSections = [.init()]
                    }
                    draft.ingredientSections[0].ingredients.append(
                        IngredientDraft(originalText: "", itemName: "", confidence: 1)
                    )
                }
                .buttonStyle(.glass)
            }

            ForEach($draft.ingredientSections) { $section in
                if draft.ingredientSections.count > 1 {
                    TextField(
                        "Nome sezione",
                        text: Binding(
                            get: { section.title ?? "" },
                            set: { section.title = $0.isEmpty ? nil : $0 }
                        )
                    )
                    .font(.headline)
                }

                ForEach($section.ingredients) { $ingredient in
                    HStack(alignment: .firstTextBaseline) {
                        TextField("Quantità", text: Binding(
                            get: { ingredient.quantityText ?? "" },
                            set: {
                                ingredient.quantityText = $0.isEmpty ? nil : $0
                                let range = DecimalParser.parseRange($0)
                                ingredient.quantity = range.minimum
                                ingredient.quantityMax = range.maximum
                            }
                        ))
                        .frame(maxWidth: 82)
                        .textFieldStyle(.roundedBorder)

                        TextField("Unità", text: Binding(
                            get: { ingredient.unit ?? "" },
                            set: { ingredient.unit = $0.isEmpty ? nil : $0 }
                        ))
                        .frame(maxWidth: 82)
                        .textFieldStyle(.roundedBorder)

                        TextField("Ingrediente", text: $ingredient.itemName, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
        }
    }

    private var stepEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Procedimento")
                    .font(.title2.bold())
                Spacer()
                Button("Aggiungi", systemImage: "plus") {
                    draft.steps.append(StepDraft(instruction: "", confidence: 1))
                }
                .buttonStyle(.glass)
            }

            ForEach(Array(draft.steps.indices), id: \.self) { index in
                HStack(alignment: .top) {
                    Text("\(index + 1)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(DishDColor.herbStrong)
                        .frame(width: 28, height: 28)
                        .background(DishDColor.herb.opacity(0.15), in: Circle())
                    TextField(
                        "Descrivi il passaggio",
                        text: $draft.steps[index].instruction,
                        axis: .vertical
                    )
                    .textFieldStyle(.roundedBorder)
                }
            }
        }
    }
}

struct ConfidenceBadge: View {
    let draft: RecipeDraft

    var body: some View {
        Label(label, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
    }

    private var label: String {
        if !draft.isRecipe || draft.confidence < 0.45 { return "Informazioni insufficienti" }
        if draft.requiresReview { return "Controlla alcuni dettagli" }
        return "Pronta"
    }

    private var symbol: String {
        draft.requiresReview ? "exclamationmark.triangle" : "checkmark.circle"
    }

    private var color: Color {
        draft.requiresReview ? .orange : .green
    }
}

struct ReviewIssueCard: View {
    let issue: UnresolvedFieldDraft

    var body: some View {
        Label(issue.message, systemImage: "questionmark.circle")
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
    }
}
