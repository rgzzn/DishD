import SwiftUI
import SwiftData
import ImagePlayground

struct RecipeDetailView: View {
    @Bindable var recipe: RecipeEntity
    @Environment(\.modelContext) private var modelContext
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @State private var servings: Decimal?
    @State private var addedToGrocery = false
    @State private var showingArtworkGenerator = false
    @State private var artworkError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                hero
                metrics
                ingredientContent
                stepContent

                if !recipe.unresolvedFields.isEmpty {
                    unresolvedContent
                }

                NavigationLink {
                    CookingModeView(recipe: recipe)
                } label: {
                    Label("Avvia modalità cucina", systemImage: "flame")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
            }
            .padding()
        }
        .background(DishDColor.canvas.ignoresSafeArea())
        .navigationTitle("Dettaglio")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    recipe.favorite.toggle()
                    recipe.updatedAt = .now
                    try? modelContext.save()
                } label: {
                    Label("Preferita", systemImage: recipe.favorite ? "heart.fill" : "heart")
                }
                .buttonStyle(.glass)

                Menu {
                    Button("Rigenera copertina", systemImage: "photo.badge.sparkles") {
                        if supportsImagePlayground {
                            showingArtworkGenerator = true
                        } else {
                            artworkError = "Image Playground non è disponibile su questo dispositivo."
                        }
                    }
                    Button("Aggiungi ingredienti alla spesa", systemImage: "cart.badge.plus") {
                        addToGroceryList()
                    }
                    if let urlString = recipe.sourceURLString, let url = URL(string: urlString) {
                        Link("Apri fonte originale", destination: url)
                    }
                } label: {
                    Label("Azioni", systemImage: "ellipsis")
                }
            }
        }
        .alert("Aggiunti alla spesa", isPresented: $addedToGrocery) {
            Button("OK", role: .cancel) {}
        }
        .alert("Copertina non disponibile", isPresented: Binding(
            get: { artworkError != nil },
            set: { if !$0 { artworkError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(artworkError ?? "")
        }
        .modifier(
            RecipeDetailImagePlaygroundSheet(
                isPresented: $showingArtworkGenerator,
                recipe: recipe,
                sourceImageURL: RecipeArtworkStore.persistentURL(
                    for: recipe.heroImageRelativePath
                ),
                onCompletion: acceptGeneratedArtwork
            )
        )
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            LocalRecipeArtworkView(
                url: RecipeArtworkStore.persistentURL(for: recipe.heroImageRelativePath)
            )
            .frame(height: 230)

            Text(recipe.title)
                .font(.largeTitle.bold())
                .foregroundStyle(DishDColor.ink)
            if let summary = recipe.summary {
                Text(summary)
                    .foregroundStyle(DishDColor.secondaryInk)
            }
            if let source = recipe.sourceAttribution ?? recipe.sourceTitle {
                Label(source, systemImage: "link")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var metrics: some View {
        HStack(spacing: 16) {
            if let total = recipe.totalTimeSeconds {
                TimeMetricView(title: "Tempo", value: total.formattedDuration, symbol: "clock")
            }
            ServingsStepper(
                servings: Binding(
                    get: { servings ?? recipe.servings ?? 1 },
                    set: { servings = $0 }
                )
            )
        }
    }

    private var ingredientContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ingredienti")
                .font(.title2.bold())
            ForEach(recipe.ingredientSections.sorted { $0.sortIndex < $1.sortIndex }) { section in
                IngredientSectionCard(
                    section: section,
                    originalServings: recipe.servings,
                    targetServings: servings ?? recipe.servings
                )
            }
        }
    }

    private var stepContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Procedimento")
                .font(.title2.bold())
            ForEach(recipe.steps.sorted { $0.sortIndex < $1.sortIndex }) { step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(step.sortIndex + 1)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(DishDColor.herbStrong)
                        .frame(width: 32, height: 32)
                        .background(DishDColor.herb.opacity(0.16), in: Circle())
                    VStack(alignment: .leading, spacing: 8) {
                        Text(step.instruction)
                        if let duration = step.durationSeconds {
                            Label(duration.formattedDuration, systemImage: "timer")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .dishdCard()
            }
        }
    }

    private var unresolvedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Da controllare", systemImage: "exclamationmark.triangle")
                .font(.headline)
                .foregroundStyle(.orange)
            ForEach(recipe.unresolvedFields) { issue in
                Text(issue.message)
                    .font(.subheadline)
            }
        }
        .dishdCard()
    }

    private func addToGroceryList() {
        let descriptor = FetchDescriptor<GroceryListEntity>()
        let list = (try? modelContext.fetch(descriptor).first) ?? GroceryListEntity()
        if list.modelContext == nil {
            modelContext.insert(list)
        }
        for ingredient in recipe.ingredientSections.flatMap(\.ingredients) {
            list.items.append(
                GroceryItemEntity(
                    name: ingredient.itemName,
                    quantityText: displayedQuantity(for: ingredient),
                    category: ingredient.groceryCategory,
                    sourceSummary: recipe.title
                )
            )
        }
        try? modelContext.save()
        addedToGrocery = true
    }

    private func displayedQuantity(for ingredient: IngredientEntity) -> String? {
        IngredientQuantityFormatter.label(
            for: ingredient,
            originalServings: recipe.servings,
            targetServings: servings ?? recipe.servings
        )
    }

    private func acceptGeneratedArtwork(_ url: URL) {
        do {
            recipe.heroImageRelativePath = try RecipeArtworkStore.persistGeneratedImage(
                from: url,
                recipeID: recipe.id
            )
            recipe.updatedAt = .now
            try modelContext.save()
            artworkError = nil
        } catch {
            artworkError = "La nuova immagine non è stata salvata. Riprova."
        }
    }
}

private struct RecipeDetailImagePlaygroundSheet: ViewModifier {
    @Binding var isPresented: Bool
    let recipe: RecipeEntity
    let sourceImageURL: URL?
    let onCompletion: (URL) -> Void

    func body(content: Content) -> some View {
        Group {
            if let sourceImageURL {
                content.imagePlaygroundSheet(
                    isPresented: $isPresented,
                    concepts: RecipeArtworkPromptBuilder.concepts(for: recipe),
                    sourceImageURL: sourceImageURL,
                    onCompletion: onCompletion
                )
            } else {
                content.imagePlaygroundSheet(
                    isPresented: $isPresented,
                    concepts: RecipeArtworkPromptBuilder.concepts(for: recipe),
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

struct IngredientSectionCard: View {
    let section: IngredientSectionEntity
    let originalServings: Decimal?
    let targetServings: Decimal?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var ingredients: [IngredientEntity] {
        section.ingredients.sorted { $0.sortIndex < $1.sortIndex }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title = section.title {
                Text(title)
                    .font(.headline)
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 14) {
                    ForEach(ingredients) { ingredient in
                        IngredientRow(
                            ingredient: ingredient,
                            originalServings: originalServings,
                            targetServings: targetServings,
                            stacked: true
                        )
                        if ingredient.id != ingredients.last?.id {
                            Divider()
                        }
                    }
                }
            } else {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        Text("QUANTITÀ")
                            .gridColumnAlignment(.leading)
                        Text("INGREDIENTE")
                            .gridColumnAlignment(.leading)
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                    Divider()
                        .gridCellColumns(2)

                    ForEach(ingredients) { ingredient in
                        IngredientRow(
                            ingredient: ingredient,
                            originalServings: originalServings,
                            targetServings: targetServings
                        )
                        if ingredient.id != ingredients.last?.id {
                            Divider()
                                .gridCellColumns(2)
                        }
                    }
                }
            }
        }
        .dishdCard()
    }
}

struct IngredientRow: View {
    let ingredient: IngredientEntity
    let originalServings: Decimal?
    let targetServings: Decimal?
    var stacked = false

    var body: some View {
        if stacked {
            VStack(alignment: .leading, spacing: 2) {
                Text("Quantità")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                IngredientQuantityBadge(text: quantityLabel)
                ingredientName
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        } else {
            GridRow {
                IngredientQuantityBadge(text: quantityLabel)
                ingredientName
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var ingredientName: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(ingredient.itemName)
                .font(.body)
                .foregroundStyle(DishDColor.ink)
            if let preparation = ingredient.preparation {
                Text(preparation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if ingredient.optional {
                Text("Facoltativo")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DishDColor.blueberry)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quantityLabel: String {
        IngredientQuantityFormatter.label(
            for: ingredient,
            originalServings: originalServings,
            targetServings: targetServings
        ) ?? "Non indicata"
    }
}

struct IngredientQuantityBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(DishDColor.herbStrong)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(minWidth: 92, alignment: .leading)
            .background(DishDColor.herb.opacity(0.13), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityLabel("Quantità \(text)")
    }
}

enum IngredientQuantityFormatter {
    static func label(
        for ingredient: IngredientEntity,
        originalServings: Decimal?,
        targetServings: Decimal?
    ) -> String? {
        if let quantity = ingredient.quantity {
            let scaled: Decimal
            if let originalServings, let targetServings, originalServings > 0 {
                scaled = quantity * targetServings / originalServings
            } else {
                scaled = quantity
            }
            return [scaled.formatted(.number.precision(.fractionLength(0...2))), ingredient.unit]
                .compactMap { $0 }
                .joined(separator: " ")
                .nilIfBlank
        }

        let original = ingredient.originalText
            .replacingOccurrences(
                of: ingredient.itemName,
                with: "",
                options: [.caseInsensitive, .diacriticInsensitive]
            )
            .replacingOccurrences(of: #"^[\s,;:–-]+|[\s,;:–-]+$"#, with: "", options: .regularExpression)
        if !original.isEmpty {
            return original
        }
        return ingredient.unit?.nilIfBlank
    }
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

struct ServingsStepper: View {
    @Binding var servings: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Porzioni", systemImage: "person.2")
                .font(.caption)
                .foregroundStyle(.secondary)
            Stepper(
                servings.formatted(.number),
                value: Binding(
                    get: { max(1, NSDecimalNumber(decimal: servings).intValue) },
                    set: { servings = Decimal($0) }
                ),
                in: 1...24
            )
            .font(.headline.monospacedDigit())
        }
        .dishdCard()
    }
}

struct TimeMetricView: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
        }
        .dishdCard()
    }
}
