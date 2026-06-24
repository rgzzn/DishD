import SwiftUI
import SwiftData

struct LibraryView: View {
    let onImport: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecipeEntity.updatedAt, order: .reverse) private var recipes: [RecipeEntity]
    @State private var searchText = ""
    @State private var favoritesOnly = false
    @State private var recipeToDelete: RecipeEntity? = nil
    @State private var showingDeleteConfirmation = false

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
                        LazyVStack(spacing: 14) {
                            ForEach(filteredRecipes) { recipe in
                                SwipeableRecipeCard(recipe: recipe) {
                                    recipeToDelete = recipe
                                    showingDeleteConfirmation = true
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 8)
                        .padding(.bottom, 28)
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
                        Image(systemName: favoritesOnly ? "heart.fill" : "heart")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(favoritesOnly ? .red : DishDColor.herbStrong)
                            .frame(width: 44, height: 44)
                            .background(DishDColor.surfaceElevated, in: Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Preferite")
                    .accessibilityValue(favoritesOnly ? "Filtro attivo" : "Filtro non attivo")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onImport) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(DishDColor.herbStrong, in: Circle())
                            .shadow(color: DishDColor.herbStrong.opacity(0.22), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Importa")
                }
            }
            .confirmationDialog(
                "Eliminare questa ricetta?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible,
                presenting: recipeToDelete
            ) { recipe in
                Button("Elimina", role: .destructive) {
                    if let path = recipe.heroImageRelativePath {
                        RecipeArtworkStore.deleteArtwork(for: path)
                    }
                    modelContext.delete(recipe)
                    try? modelContext.save()
                    recipeToDelete = nil
                }
                Button("Annulla", role: .cancel) {
                    recipeToDelete = nil
                }
            } message: { recipe in
                Text("Sei sicuro di voler eliminare \"\(recipe.title)\"? Questa azione non può essere annullata.")
            }
        }
    }
}

private struct SwipeableRecipeCard: View {
    let recipe: RecipeEntity
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isSwiped = false

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive) {
                withAnimation(.spring()) {
                    offset = 0
                    isSwiped = false
                }
                onDelete()
            } label: {
                Image(systemName: "trash.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 80, height: .infinity)
                    .frame(maxHeight: .infinity)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: DishDRadius.card, style: .continuous))
            }
            .padding(.vertical, 1)
            .padding(.trailing, 1)

            NavigationLink {
                RecipeDetailView(recipe: recipe)
            } label: {
                RecipeCard(recipe: recipe)
            }
            .buttonStyle(.plain)
            .offset(x: offset)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { gesture in
                        let translation = gesture.translation.width
                        let newOffset = isSwiped ? translation - 90 : translation
                        if newOffset < 0 {
                            if newOffset < -90 {
                                offset = -90 + (newOffset + 90) * 0.3
                            } else {
                                offset = newOffset
                            }
                        } else {
                            offset = 0
                        }
                    }
                    .onEnded { gesture in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if offset < -50 {
                                offset = -90
                                isSwiped = true
                            } else {
                                offset = 0
                                isSwiped = false
                            }
                        }
                    }
            )
        }
    }
}
