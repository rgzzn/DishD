import SwiftUI
import SwiftData

struct LibraryView: View {
    let onImport: () -> Void
    @Query(sort: \RecipeEntity.updatedAt, order: .reverse) private var recipes: [RecipeEntity]
    @State private var searchText = ""
    @State private var favoritesOnly = false

    private var filteredRecipes: [RecipeEntity] {
        recipes.filter { recipe in
            let matchesFavorite = !favoritesOnly || recipe.favorite
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return matchesFavorite }
            let searchable = [
                recipe.title,
                recipe.cuisine ?? "",
                recipe.sourceTitle ?? "",
                recipe.notes ?? ""
            ] + recipe.ingredientSections.flatMap(\.ingredients).map(\.itemName)
            return matchesFavorite && searchable.contains {
                $0.localizedCaseInsensitiveContains(query)
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if recipes.isEmpty {
                    EmptyStateView(
                        title: "Il tuo ricettario è vuoto",
                        message: "Incolla un testo o un link pubblico. DishD prova prima i dati strutturati e usa l’AI locale quando disponibile.",
                        buttonTitle: "Importa la prima ricetta",
                        action: onImport
                    )
                } else if filteredRecipes.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 260), spacing: 16)],
                            spacing: 16
                        ) {
                            ForEach(filteredRecipes) { recipe in
                                NavigationLink {
                                    RecipeDetailView(recipe: recipe)
                                } label: {
                                    RecipeCard(recipe: recipe)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(DishDColor.canvas.ignoresSafeArea())
            .navigationTitle("Ricette")
            .searchable(text: $searchText, prompt: "Titolo, ingrediente o fonte")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        favoritesOnly.toggle()
                    } label: {
                        Label("Preferite", systemImage: favoritesOnly ? "heart.fill" : "heart")
                    }
                    .buttonStyle(.glass)
                    .accessibilityValue(favoritesOnly ? "Filtro attivo" : "Filtro non attivo")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onImport) {
                        Label("Importa", systemImage: "plus")
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
    }
}
