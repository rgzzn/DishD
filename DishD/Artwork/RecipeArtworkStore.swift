import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum RecipeArtworkStore {
    private static let artworkDirectoryName = "RecipeArtwork"

    static func makeTemporaryImage(from data: Data) throws -> URL {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0
        else {
            throw ImportError.unsupportedContent
        }

        let typeIdentifier = CGImageSourceGetType(source) as String?
        let fileExtension = typeIdentifier
            .flatMap(UTType.init)
            .flatMap(\.preferredFilenameExtension)
            ?? "jpg"
        let destination = FileManager.default.temporaryDirectory
            .appending(path: "dishd-source-\(UUID().uuidString).\(fileExtension)")
        try data.write(to: destination, options: [.atomic])
        return destination
    }

    static func makeTemporaryImage(from image: CGImage) throws -> URL {
        let destination = FileManager.default.temporaryDirectory
            .appending(path: "dishd-frame-\(UUID().uuidString).jpg")
        guard let writer = CGImageDestinationCreateWithURL(
            destination as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ImportError.extractionFailed
        }
        CGImageDestinationAddImage(
            writer,
            image,
            [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary
        )
        guard CGImageDestinationFinalize(writer) else {
            throw ImportError.extractionFailed
        }
        return destination
    }

    static func copyToTemporaryStorage(from sourceURL: URL) throws -> URL {
        let data = try Data(contentsOf: sourceURL, options: [.mappedIfSafe])
        return try makeTemporaryImage(from: data)
    }

    static func persistGeneratedImage(
        from sourceURL: URL,
        recipeID: UUID
    ) throws -> String {
        let data = try Data(contentsOf: sourceURL, options: [.mappedIfSafe])
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0
        else {
            throw ImportError.unsupportedContent
        }

        let typeIdentifier = CGImageSourceGetType(source) as String?
        let fileExtension = typeIdentifier
            .flatMap(UTType.init)
            .flatMap(\.preferredFilenameExtension)
            ?? "png"
        let relativePath = "\(artworkDirectoryName)/\(recipeID.uuidString).\(fileExtension)"
        let destination = try applicationSupportDirectory()
            .appending(path: relativePath)
        let artworkDirectory = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: artworkDirectory,
            withIntermediateDirectories: true
        )
        let previousImages = try FileManager.default.contentsOfDirectory(
            at: artworkDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        for previousImage in previousImages
        where previousImage.deletingPathExtension().lastPathComponent == recipeID.uuidString {
            try? FileManager.default.removeItem(at: previousImage)
        }
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try data.write(to: destination, options: [.atomic, .completeFileProtection])
        return relativePath
    }

    static func persistentURL(for relativePath: String?) -> URL? {
        guard let relativePath,
              let root = try? applicationSupportDirectory()
        else {
            return nil
        }
        let url = root.appending(path: relativePath)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func deleteArtwork(for relativePath: String?) {
        guard let relativePath,
              let root = try? applicationSupportDirectory()
        else {
            return
        }
        let url = root.appending(path: relativePath)
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func applicationSupportDirectory() throws -> URL {
        guard let directory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }
}
