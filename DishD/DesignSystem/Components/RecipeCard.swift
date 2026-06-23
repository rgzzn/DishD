import SwiftUI

struct RecipeCard: View {
    let recipe: RecipeEntity
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 22).fill(DishDColor.herb.opacity(0.18)).frame(height: 120).overlay(Image(systemName: "fork.knife").font(.largeTitle).foregroundStyle(DishDColor.herb))
            Text(recipe.title).font(.title3.weight(.semibold)).foregroundStyle(DishDColor.ink).lineLimit(2)
            HStack { if let servings = recipe.servings { Label("\(servings.description) porzioni", systemImage: "person.2") }; if recipe.requiresReview { Label("Da controllare", systemImage: "exclamationmark.triangle") } }.font(.caption).foregroundStyle(DishDColor.secondaryInk)
        }.padding().background(DishDColor.surfaceElevated).clipShape(RoundedRectangle(cornerRadius: 24)).accessibilityElement(children: .combine).accessibilityLabel("Ricetta \(recipe.title)")
    }
}
