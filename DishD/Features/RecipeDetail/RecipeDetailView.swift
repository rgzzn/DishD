import SwiftUI

struct RecipeDetailView: View {
    let recipe: RecipeEntity
    @State private var servings: Decimal?
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 20) {
            Text(recipe.title).font(.largeTitle.bold())
            if let url = recipe.sourceURLString { Label(url, systemImage: "link").font(.footnote).foregroundStyle(.secondary) }
            ServingsStepper(servings: Binding(get: { servings ?? recipe.servings ?? 1 }, set: { servings = $0 }))
            ForEach(recipe.ingredientSections.sorted { $0.sortIndex < $1.sortIndex }) { section in VStack(alignment: .leading) { if let title = section.title { Text(title).font(.headline) }; ForEach(section.ingredients.sorted { $0.sortIndex < $1.sortIndex }) { ingredient in IngredientRow(ingredient: ingredient, originalServings: recipe.servings, targetServings: servings ?? recipe.servings) } } }
            Text("Procedimento").font(.title2.bold())
            ForEach(recipe.steps.sorted { $0.sortIndex < $1.sortIndex }) { step in Text(step.instruction).padding().frame(maxWidth: .infinity, alignment: .leading).background(DishDColor.surface).clipShape(RoundedRectangle(cornerRadius: 18)) }
            NavigationLink("Avvia modalità cucina") { CookingModeView(recipe: recipe) }.buttonStyle(.borderedProminent)
        }.padding() }.navigationTitle("Dettaglio").navigationBarTitleDisplayMode(.inline).background(DishDColor.canvas)
    }
}
struct IngredientRow: View { let ingredient: IngredientEntity; let originalServings: Decimal?; let targetServings: Decimal?; var body: some View { HStack { Text(scaledQuantity()); Text(ingredient.itemName); Spacer() }.padding(.vertical, 4) } private func scaledQuantity() -> String { guard let q = ingredient.quantity, let original = originalServings, let target = targetServings, original > 0 else { return ingredient.originalText == ingredient.itemName ? "" : ingredient.originalText.replacingOccurrences(of: ingredient.itemName, with: "") }; return (q * target / original).description + (ingredient.unit.map { " \($0)" } ?? "") } }
struct ServingsStepper: View { @Binding var servings: Decimal; var body: some View { Stepper("Porzioni: \(servings.description)", value: Binding(get: { Int(truncating: servings as NSNumber) }, set: { servings = Decimal($0) }), in: 1...24).accessibilityLabel("Porzioni") } }
