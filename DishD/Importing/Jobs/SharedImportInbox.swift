import Foundation

actor SharedImportInbox {
    private let groupIdentifier = AppBrand.appGroupIdentifier

    func consumeNext() -> PendingSharedImport? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupIdentifier
        ) else {
            return nil
        }
        let directory = container.appending(path: "PendingImports", directoryHint: .isDirectory)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }
        let payloadFiles = files
            .filter { $0.pathExtension == "json" }
            .sorted { left, right in
                let leftDate = (try? left.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rightDate = (try? right.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return leftDate < rightDate
            }
        guard let file = payloadFiles.first,
              let data = try? Data(contentsOf: file),
              let payload = try? JSONDecoder().decode(SharedImportPayload.self, from: data)
        else {
            return nil
        }
        try? FileManager.default.removeItem(at: file)

        let parts = payload.texts + payload.urls + [payload.note].compactMap { $0 }
        let combined = parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        let fileURL = payload.files.first.map {
            directory
                .appending(path: "Files", directoryHint: .isDirectory)
                .appending(path: $0)
        }
        guard !combined.isEmpty || fileURL != nil else { return nil }
        return PendingSharedImport(
            text: combined.isEmpty ? nil : combined,
            fileURL: fileURL
        )
    }
}

struct PendingSharedImport: Sendable {
    let text: String?
    let fileURL: URL?
}

private struct SharedImportPayload: Codable {
    let createdAt: Date
    let texts: [String]
    let urls: [String]
    let files: [String]
    let note: String?
}
