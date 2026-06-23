import SwiftUI

struct RecipeReviewView: View {
    let draft: RecipeDraft
    let onSave: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !draft.isRecipe { Label("Il contenuto non contiene ingredienti e procedimento sufficienti.", systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
            Text(draft.title).font(.title2.bold())
            if let servings = draft.servings { Label("\(servings.description) porzioni", systemImage: "person.2") }
            Text("Ingredienti").font(.headline)
            ForEach(draft.ingredients) { Text("• \($0.originalText)") }
            Text("Passaggi").font(.headline)
            ForEach(Array(draft.steps.enumerated()), id: \.element.id) { index, step in Text("\(index + 1). \(step.instruction)") }
            if !draft.unresolved.isEmpty { VStack(alignment: .leading) { Text("Da controllare").font(.headline); ForEach(draft.unresolved, id: \.self) { Label($0, systemImage: "questionmark.circle") } }.padding().background(.orange.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 16)) }
            Button("Salva ricetta", action: onSave).buttonStyle(.borderedProminent).disabled(!draft.isRecipe)
        }.padding().background(DishDColor.surfaceElevated).clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
