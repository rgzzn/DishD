import SwiftUI
import UIKit

struct CookingModeView: View {
    let recipe: RecipeEntity
    @State private var index = 0
    @State private var completed: Set<UUID> = []

    private var steps: [RecipeStepEntity] {
        recipe.steps.sorted { $0.sortIndex < $1.sortIndex }
    }

    var body: some View {
        VStack(spacing: 24) {
            if steps.isEmpty {
                ContentUnavailableView(
                    "Nessun passaggio",
                    systemImage: "list.number",
                    description: Text("Aggiungi il procedimento prima di avviare la modalità cucina.")
                )
            } else {
                ProgressView(value: Double(index + 1), total: Double(steps.count))
                    .tint(DishDColor.herbStrong)
                Text("Passaggio \(index + 1) di \(steps.count)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(steps[index].instruction)
                    .font(.largeTitle.weight(.semibold))
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
                    .padding()
                if let duration = steps[index].durationSeconds {
                    Label(duration.formattedDuration, systemImage: "timer")
                        .font(.title3.monospacedDigit())
                }
                Spacer()
                HStack {
                    Button("Indietro", systemImage: "chevron.left") {
                        index = max(0, index - 1)
                    }
                    .buttonStyle(.glass)
                    .disabled(index == 0)

                    Button(completed.contains(steps[index].id) ? "Completato" : "Completa", systemImage: "checkmark") {
                        completed.insert(steps[index].id)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        if index < steps.count - 1 {
                            withAnimation { index += 1 }
                        }
                    }
                    .buttonStyle(.glassProminent)

                    Button("Avanti", systemImage: "chevron.right") {
                        index = min(steps.count - 1, index + 1)
                    }
                    .buttonStyle(.glass)
                    .disabled(index == steps.count - 1)
                }
            }
        }
        .padding()
        .background(DishDColor.canvas.ignoresSafeArea())
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}
