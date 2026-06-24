import Foundation
import UIKit

enum SharedImportPasteboardReader {
    private static let marker = "dishd-shared-import-v1\n"
    private static let pasteboardName = UIPasteboard.Name("com.lucaragazzini.dishd.share")
    private static let consumedKey = "DishD.consumedPasteboardImportIDs"

    static func consume() -> String? {
        guard let value = payloadString(),
              value.hasPrefix(marker),
              let data = String(value.dropFirst(marker.count)).data(using: .utf8),
              let payload = try? JSONDecoder().decode(PasteboardPayload.self, from: data),
              payload.createdAt.timeIntervalSinceNow > -600,
              !consumedIDs.contains(payload.id)
        else {
            return nil
        }

        var consumed = consumedIDs
        consumed.insert(payload.id)
        UserDefaults.standard.set(Array(consumed), forKey: consumedKey)

        let combined = [payload.input, payload.note]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        return combined.isEmpty ? nil : combined
    }

    private static var consumedIDs: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: consumedKey) ?? [])
    }

    private static func payloadString() -> String? {
        if let value = UIPasteboard(name: pasteboardName, create: false)?.string,
           value.hasPrefix(marker) {
            return value
        }
        guard UIPasteboard.general.hasStrings else { return nil }
        return UIPasteboard.general.string
    }
}

private struct PasteboardPayload: Codable {
    let id: String
    let createdAt: Date
    let input: String?
    let note: String?
}
