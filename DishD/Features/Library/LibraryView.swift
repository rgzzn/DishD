import SwiftUI
import SwiftData

struct LibraryView: View {
    @Binding var showingImport: Bool
    @Query(sort: \RecipeEntity.updatedAt, order: .reverse) private var recipes: [RecipeEntity]
    var body: some View {
        NavigationStack {
            Group {
                if recipes.isEmpty { EmptyStateView(title: "Il tuo ricettario è vuoto", message: "Importa testo, link o contenuti condivisi. L’analisi AI resta sul dispositivo quando il modello locale è disponibile.", buttonTitle: "Importa la prima ricetta") { showingImport = true } }
                else { ScrollView { LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) { ForEach(recipes) { recipe in NavigationLink { RecipeDetailView(recipe: recipe) } label: { RecipeCard(recipe: recipe) }.buttonStyle(.plain) } }.padding() } }
            }
            .navigationTitle("Ricette")
            .toolbar { Button { showingImport = true } label: { Label("Importa", systemImage: "square.and.arrow.down") } }
            .background(DishDColor.canvas.ignoresSafeArea())
        }
    }
}
