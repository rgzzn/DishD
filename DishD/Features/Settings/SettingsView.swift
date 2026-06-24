import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var availability: RecipeModelAvailability = .temporarilyUnavailable
    @State private var confirmingDeletion = false
    let availabilityChecker: AppleSystemModelAvailabilityChecker

    var body: some View {
        NavigationStack {
            List {
                Section("Apple Intelligence") {
                    ModelAvailabilityBanner(availability: availability)
                    Button("Verifica stato modello", systemImage: "arrow.clockwise") {
                        Task { await refreshAvailability() }
                    }
                }

                Section("Privacy") {
                    Label("Elaborazione AI sul dispositivo", systemImage: "lock.shield")
                    Text("DishD non configura modelli cloud, account, analytics di terze parti o backend. La rete viene usata solo per leggere gli URL che scegli di importare.")
                }

                Section("Dati") {
                    Button("Elimina tutte le ricette", systemImage: "trash", role: .destructive) {
                        confirmingDeletion = true
                    }
                }

                Section("Informazioni") {
                    LabeledContent("Prodotto", value: AppBrand.productName)
                    LabeledContent("Lingua", value: "Italiano")
                    LabeledContent("Versione", value: "1.0")
                }
            }
            .navigationTitle("Impostazioni")
            .task { await refreshAvailability() }
            .confirmationDialog(
                "Eliminare tutte le ricette?",
                isPresented: $confirmingDeletion,
                titleVisibility: .visible
            ) {
                Button("Elimina tutto", role: .destructive) {
                    try? modelContext.delete(model: RecipeEntity.self)
                    try? modelContext.save()
                }
                Button("Annulla", role: .cancel) {}
            } message: {
                Text("Questa azione rimuove definitivamente il ricettario locale.")
            }
        }
    }

    private func refreshAvailability() async {
        availability = await availabilityChecker.availability(for: Locale(identifier: "it_IT"))
    }
}

struct ModelAvailabilityBanner: View {
    let availability: RecipeModelAvailability

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: availability == .available ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(availability == .available ? .green : .orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(availability.italianTitle)
                    .font(.headline)
                Text(availability.italianMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
