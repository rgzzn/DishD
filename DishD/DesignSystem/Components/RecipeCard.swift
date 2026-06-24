import SwiftUI

struct RecipeCard: View {
    let recipe: RecipeEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerImage

            VStack(alignment: .leading, spacing: 12) {
                titleRow
                detailRow
            }
            .padding(.horizontal, 18)
            .padding(.top, 15)
            .padding(.bottom, 17)
            .background(
                DishDColor.surfaceElevated
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(Color.black.opacity(0.04))
                            .frame(height: 1)
                    }
            )
        }
        .background(DishDColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.07), radius: 16, x: 0, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ricetta \(recipe.title)")
    }

    private var headerImage: some View {
        ZStack(alignment: .topTrailing) {
            LocalRecipeArtworkView(
                url: RecipeArtworkStore.persistentURL(for: recipe.heroImageRelativePath),
                cornerRadius: 0
            )
            .frame(height: 168)

            if recipe.favorite || recipe.requiresReview {
                HStack(spacing: 8) {
                    if recipe.requiresReview {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }

                    if recipe.favorite {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                    }
                }
                .font(.system(size: 13, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
                .padding(12)
            }
        }
    }

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(recipe.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(DishDColor.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            if let cuisine = recipe.cuisine, !cuisine.isEmpty {
                Text(cuisine)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DishDColor.herbStrong)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(DishDColor.herb.opacity(0.12), in: Capsule())
                    .lineLimit(1)
            }
        }
    }

    private var detailRow: some View {
        HStack(spacing: 16) {
            metadataRow
            Spacer(minLength: 0)

            if recipe.requiresReview {
                Label("Controlla", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.orange)
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(DishDColor.secondaryInk)
    }

    private var metadataRow: some View {
        HStack(spacing: 15) {
            if let total = recipe.totalTimeSeconds {
                RecipeMetadataItem(
                    systemImage: "clock",
                    text: total.formattedDuration
                )
            }

            if let servings = recipe.servings {
                RecipeMetadataItem(
                    systemImage: "person.2",
                    text: "\(servings.formatted(.number)) porzioni"
                )
            }
        }
    }
}

private struct RecipeMetadataItem: View {
    let systemImage: String
    let text: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .labelStyle(.titleAndIcon)
            .symbolRenderingMode(.hierarchical)
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
