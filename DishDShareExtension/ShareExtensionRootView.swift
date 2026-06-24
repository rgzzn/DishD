import SwiftUI

@MainActor
@Observable
final class ShareExtensionModel {
    var note = ""
    var items: [CollectedShareItem] = []
    var isLoading = true
    var isSaving = false
    var errorMessage: String?

    private let collector = SharedItemCollector()

    func load(_ extensionItems: [NSExtensionItem]) async {
        await collector.collect(from: extensionItems)
        items = collector.items
        isLoading = false
    }

    func save() throws -> SharedSaveResult {
        isSaving = true
        defer { isSaving = false }
        return try collector.save(note: note)
    }
}

struct ShareExtensionRootView: View {
    @State var model: ShareExtensionModel
    let onCancel: () -> Void
    let onComplete: (SharedSaveResult) -> Void

    var body: some View {
        NavigationStack {
            Form {
                if model.isLoading {
                    ProgressView("Leggo gli elementi condivisi")
                } else if model.items.isEmpty {
                    ContentUnavailableView(
                        "Nessun contenuto supportato",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Condividi testo, un link, un’immagine, un video o un file.")
                    )
                } else {
                    Section("Contenuti") {
                        ForEach(model.items) { item in
                            Label {
                                VStack(alignment: .leading) {
                                    Text(item.title)
                                    Text(item.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            } icon: {
                                Image(systemName: item.symbol)
                            }
                        }
                    }
                    Section("Nota opzionale") {
                        TextField("Aggiungi un contesto", text: $model.note, axis: .vertical)
                    }
                }
                if let error = model.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Salva in DishD")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        do {
                            let result = try model.save()
                            onComplete(result)
                        } catch {
                            model.errorMessage = "Non è stato possibile salvare nella coda di DishD."
                        }
                    }
                    .disabled(model.items.isEmpty || model.isLoading || model.isSaving)
                }
            }
        }
    }
}
