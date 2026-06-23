import SwiftUI

struct CookingModeView: View { let recipe: RecipeEntity; @State private var index = 0; var sortedSteps: [RecipeStepEntity] { recipe.steps.sorted { $0.sortIndex < $1.sortIndex } }; var body: some View { VStack(spacing: 24) { if sortedSteps.isEmpty { Text("Nessun passaggio disponibile") } else { Text("Passaggio \(index + 1) di \(sortedSteps.count)").font(.headline); Text(sortedSteps[index].instruction).font(.title2).multilineTextAlignment(.center).padding(); HStack { Button("Indietro") { index = max(0, index - 1) }.disabled(index == 0); Button("Avanti") { index = min(sortedSteps.count - 1, index + 1) }.disabled(index == sortedSteps.count - 1) } } }.padding().navigationTitle("Cucina") }
}
