import SwiftUI

struct RecipeCard: View {
    let recipe: RecipeEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LocalRecipeArtworkView(
                url: RecipeArtworkStore.persistentURL(for: recipe.heroImageRelativePath)
            )
            .frame(height: 132)

            Text(recipe.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(DishDColor.ink)
                .lineLimit(2)

            HStack(spacing: 12) {
                if let total = recipe.totalTimeSeconds {
                    Label(total.formattedDuration, systemImage: "clock")
                }
                if let servings = recipe.servings {
                    Label("\(servings.formatted(.number))", systemImage: "person.2")
                }
                if recipe.requiresReview {
                    Label("Da controllare", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption)
            .foregroundStyle(DishDColor.secondaryInk)
        }
        .dishdCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ricetta \(recipe.title)")
    }
}

extension Int {
    var formattedDuration: String {
        let hours = self / 3600
        let minutes = (self % 3600) / 60
        if hours > 0 && minutes > 0 { return "\(hours) h \(minutes) min" }
        if hours > 0 { return "\(hours) h" }
        return "\(Swift.max(1, minutes)) min"
    }
}
