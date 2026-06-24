import Foundation
import LinkPresentation
import UIKit
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
    private(set) var collectionWarnings: [String] = []
    private let linkMetadataTypeIdentifier = "com.apple.linkpresentation.metadata"

    func collect(from extensionItems: [NSExtensionItem]) async {
        for extensionItem in extensionItems {
            if let attributed = extensionItem.attributedContentText?.string {
                appendText(attributed)
            }
            for provider in extensionItem.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(linkMetadataTypeIdentifier),
                   let metadata = try? await provider.dishdLoadLinkMetadata() {
                    appendLinkMetadata(metadata)
                    continue
                }
                if let type = preferredFileType(for: provider) {
                    do {
                        let file = try await provider.dishdPersistFile(for: type)
                        appendFileItem(name: file.name, originalName: file.originalName, type: type)
                    } catch {
                        // Don't let a failed copy (e.g. a large video exceeding the
                        // extension's memory budget) silently drop the file.
                        collectionWarnings.append(
                            "Non sono riuscito a copiare un file condiviso. Se è un video lungo, salvalo nei File e condividilo da lì."
                        )
                    }
                    continue
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let text = try? await provider.dishdLoadText() {
                    appendText(text)
                    continue
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let url = try? await provider.dishdLoadURL() {
                    appendURL(url)
                    continue
                }
                if let url = try? await provider.dishdLoadURLFromAnySupportedType() {
                    appendURL(url)
                    continue
                }
                if let text = try? await provider.dishdLoadTextFromAnySupportedType() {
                    appendText(text)
                }
            }
        }
    }

    func save(note: String?) throws -> SharedSaveResult {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.lucaragazzini.dishd"
        ) else {
            if let fallback = fallbackPayload(note: note) {
                SharedImportPasteboardWriter.write(input: fallback.input, note: fallback.note)
                let url = fallbackDeepLink(input: fallback.input, note: fallback.note)
                return .openContainingApp(url)
            }
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
        return .queued
    }

    private func appendText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !texts.contains(trimmed) else { return }
        texts.append(trimmed)
        items.append(.init(title: "Testo", detail: String(trimmed.prefix(90)), symbol: "text.alignleft"))
    }

    private func appendURL(_ url: URL) {
        let value = url.absoluteString
        guard !urls.contains(value) else { return }
        urls.append(value)
        items.append(.init(title: "Link", detail: url.host ?? value, symbol: "link"))
    }

    private func appendLinkMetadata(_ metadata: SharedLinkMetadata) {
        if let title = metadata.title {
            appendText(title)
        }
        if let originalURL = metadata.originalURL {
            appendURL(originalURL)
        } else if let url = metadata.url {
            appendURL(url)
        }
        if let remoteVideoURL = metadata.remoteVideoURL {
            items.append(
                .init(
                    title: "Video remoto",
                    detail: remoteVideoURL.host ?? remoteVideoURL.absoluteString,
                    symbol: "video"
                )
            )
        }
    }

    private func preferredFileType(for provider: NSItemProvider) -> UTType? {
        // Prefer the provider's CONCRETE registered type (e.g. public.mpeg-4, public.jpeg)
        // so the persisted file gets a correct, recognizable filename extension. Falling
        // back to the abstract supertype guarantees we still persist something usable.
        for supertype in [UTType.movie, .image, .pdf] {
            let concrete = provider.registeredTypeIdentifiers
                .compactMap { UTType($0) }
                .first { $0.conforms(to: supertype) }
            if let concrete {
                return concrete
            }
            if provider.hasItemConformingToTypeIdentifier(supertype.identifier) {
                return supertype
            }
        }
        return nil
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

    private func fallbackPayload(note: String?) -> (input: String, note: String?)? {
        let input = (texts + urls)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        let note = note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
        guard !input.isEmpty || note != nil else { return nil }
        return (String(input.prefix(6_000)), note)
    }

    private func fallbackDeepLink(input: String, note: String?) -> URL {
        var components = URLComponents()
        components.scheme = "dishd"
        components.host = "import"
        components.queryItems = [
            URLQueryItem(name: "input", value: String(input.prefix(6_000))),
            URLQueryItem(name: "note", value: note)
        ].filter { $0.value != nil }
        return components.url!
    }

}

enum SharedSaveResult {
    case queued
    case openContainingApp(URL)
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
    func dishdLoadURLFromAnySupportedType() async throws -> URL {
        for identifier in registeredTypeIdentifiers {
            if let type = UTType(identifier),
               type.conforms(to: .url),
               let url = try? await dishdLoadURL(typeIdentifier: identifier) {
                return url
            }
        }
        throw ShareError.emptyItem
    }

    @MainActor
    func dishdLoadTextFromAnySupportedType() async throws -> String {
        for identifier in registeredTypeIdentifiers {
            if let type = UTType(identifier),
               type.conforms(to: .text),
               let text = try? await dishdLoadText(typeIdentifier: identifier) {
                return text
            }
        }
        throw ShareError.emptyItem
    }

    @MainActor
    func dishdLoadLinkMetadata() async throws -> SharedLinkMetadata {
        let data: Data = try await withCheckedThrowingContinuation { continuation in
            loadDataRepresentation(forTypeIdentifier: "com.apple.linkpresentation.metadata") { data, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: ShareError.emptyItem)
                }
            }
        }
        guard let metadata = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: LPLinkMetadata.self,
            from: data
        ) else {
            throw ShareError.emptyItem
        }
        return SharedLinkMetadata(
            title: metadata.title,
            url: metadata.url,
            originalURL: metadata.originalURL,
            remoteVideoURL: metadata.remoteVideoURL
        )
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

    @MainActor
    private func dishdLoadURL(typeIdentifier: String) async throws -> URL {
        let text = try await dishdLoadItemText(typeIdentifier: typeIdentifier)
        if let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return url
        }
        throw ShareError.emptyItem
    }

    @MainActor
    private func dishdLoadText(typeIdentifier: String) async throws -> String {
        try await dishdLoadItemText(typeIdentifier: typeIdentifier)
    }

    @MainActor
    private func dishdLoadItemText(typeIdentifier: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data,
                          let text = String(data: data, encoding: .utf8)?.nilIfBlank {
                    continuation.resume(returning: text)
                } else {
                    continuation.resume(throwing: ShareError.emptyItem)
                }
            }
        }
    }
}

private enum SharedImportPasteboardWriter {
    private static let marker = "dishd-shared-import-v1\n"
    private static let pasteboardName = UIPasteboard.Name("com.lucaragazzini.dishd.share")

    static func write(input: String, note: String?) {
        let payload = PasteboardPayload(
            id: UUID().uuidString,
            createdAt: .now,
            input: input.nilIfBlank,
            note: note?.nilIfBlank
        )
        guard let data = try? JSONEncoder().encode(payload),
              let json = String(data: data, encoding: .utf8)
        else {
            return
        }
        let item = [UTType.plainText.identifier: marker + json]
        let options: [UIPasteboard.OptionsKey: Any] = [
            .localOnly: true,
            .expirationDate: Date().addingTimeInterval(600)
        ]
        UIPasteboard(name: pasteboardName, create: true)?.setItems([item], options: options)
        UIPasteboard.general.setItems([item], options: options)
    }
}

private struct PasteboardPayload: Codable {
    let id: String
    let createdAt: Date
    let input: String?
    let note: String?
}

private struct SharedLinkMetadata {
    let title: String?
    let url: URL?
    let originalURL: URL?
    let remoteVideoURL: URL?
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
        // Trust the UTType's preferred extension first so the main app's importer reliably
        // recognizes the file; fall back to the source extension, normalized to lowercase.
        let ext = (type.preferredFilenameExtension
            ?? sourceURL.pathExtension.nilIfBlank
            ?? "dat").lowercased()
        let fileName = "\(UUID().uuidString).\(ext)"
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
