import Foundation
import UniformTypeIdentifiers

struct CollectedShareItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let symbol: String
}

@MainActor
final class SharedItemCollector {
    private(set) var texts: [String] = []
    private(set) var urls: [String] = []
    private(set) var fileNames: [String] = []
    private(set) var items: [CollectedShareItem] = []

    func collect(from extensionItems: [NSExtensionItem]) async {
        for extensionItem in extensionItems {
            if let attributed = extensionItem.attributedContentText?.string {
                appendText(attributed)
            }
            for provider in extensionItem.attachments ?? [] {
                if let type = preferredFileType(for: provider),
                   let file = try? await provider.dishdPersistFile(for: type) {
                    appendFileItem(name: file.name, originalName: file.originalName, type: type)
                    continue
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let text = try? await provider.dishdLoadText() {
                    appendText(text)
                    continue
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let url = try? await provider.dishdLoadURL() {
                    urls.append(url.absoluteString)
                    items.append(.init(title: "Link", detail: url.host ?? url.absoluteString, symbol: "link"))
                }
            }
        }
    }

    func save(note: String?) throws {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.lucaragazzini.dishd"
        ) else {
            throw ShareError.appGroupUnavailable
        }
        let directory = container.appending(path: "PendingImports", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let payload = SharedImportPayload(
            createdAt: .now,
            texts: texts,
            urls: urls,
            files: fileNames,
            note: note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
        )
        let data = try JSONEncoder().encode(payload)
        try data.write(
            to: directory.appending(path: "\(UUID().uuidString).json"),
            options: [.atomic, .completeFileProtection]
        )
    }

    private func appendText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        texts.append(trimmed)
        items.append(.init(title: "Testo", detail: String(trimmed.prefix(90)), symbol: "text.alignleft"))
    }

    private func preferredFileType(for provider: NSItemProvider) -> UTType? {
        [.movie, .image, .pdf].first {
            provider.hasItemConformingToTypeIdentifier($0.identifier)
        }
    }

    private func appendFileItem(name: String, originalName: String, type: UTType) {
        fileNames.append(name)
        items.append(
            .init(
                title: type.conforms(to: .image) ? "Immagine" : type.conforms(to: .movie) ? "Video" : "File",
                detail: originalName,
                symbol: type.conforms(to: .image) ? "photo" : type.conforms(to: .movie) ? "video" : "doc"
            )
        )
    }

}

private extension NSItemProvider {
    @MainActor
    func dishdLoadURL() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            loadObject(ofClass: NSURL.self) { object, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url = object as? URL {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: ShareError.emptyItem)
                }
            }
        }
    }

    @MainActor
    func dishdLoadText() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            loadObject(ofClass: NSString.self) { object, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let text = object as? String {
                    continuation.resume(returning: text)
                } else {
                    continuation.resume(throwing: ShareError.emptyItem)
                }
            }
        }
    }

    @MainActor
    func dishdPersistFile(for type: UTType) async throws -> PersistedShareFile {
        try await withCheckedThrowingContinuation { continuation in
            loadFileRepresentation(forTypeIdentifier: type.identifier) { sourceURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let sourceURL else {
                    continuation.resume(throwing: ShareError.emptyItem)
                    return
                }
                do {
                    continuation.resume(returning: try SharedFileCopier.copy(sourceURL, type: type))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

private struct PersistedShareFile: Sendable {
    let name: String
    let originalName: String
}

private enum SharedFileCopier {
    static func copy(_ sourceURL: URL, type: UTType) throws -> PersistedShareFile {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.lucaragazzini.dishd"
        ) else {
            throw ShareError.appGroupUnavailable
        }
        let directory = container
            .appending(path: "PendingImports", directoryHint: .isDirectory)
            .appending(path: "Files", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileName = "\(UUID().uuidString).\(sourceURL.pathExtension.nilIfBlank ?? type.preferredFilenameExtension ?? "data")"
        let destination = directory.appending(path: fileName)
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return PersistedShareFile(name: fileName, originalName: sourceURL.lastPathComponent)
    }
}

private struct SharedImportPayload: Codable {
    let createdAt: Date
    let texts: [String]
    let urls: [String]
    let files: [String]
    let note: String?
}

private enum ShareError: Error {
    case appGroupUnavailable
    case emptyItem
}

private extension String {
    var nilIfBlank: String? { isEmpty ? nil : self }
}
