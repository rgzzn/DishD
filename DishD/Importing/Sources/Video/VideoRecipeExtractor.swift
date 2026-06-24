import AVFoundation
import Foundation
import Speech
import Vision

enum VideoImportPhase: Sendable {
    case preparing
    case transcribing
    case readingFrames
    case buildingEvidence

    var italianLabel: String {
        switch self {
        case .preparing: "Preparo il video"
        case .transcribing: "Ascolto il video"
        case .readingFrames: "Leggo il testo nei fotogrammi"
        case .buildingEvidence: "Riconosco ingredienti e passaggi"
        }
    }
}

struct VideoEvidence: Sendable {
    let transcript: String?
    let frameText: String?
    let referenceImageURL: URL?

    var isEmpty: Bool {
        transcript == nil && frameText == nil
    }

    func combined(with context: String?) -> String {
        [
            frameText.map { "[Testo letto nei fotogrammi]\n\($0)" },
            transcript.map { "[Trascrizione audio]\n\($0)" },
            context?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank.map {
                "[Didascalia, nota o link condiviso]\n\($0)"
            }
        ]
        .compactMap { $0 }
        .joined(separator: "\n\n")
    }
}

actor VideoRecipeExtractor {
    private let transcriber = LocalVideoTranscriber()
    private let frameReader = VideoFrameTextReader()

    func extractEvidence(
        from url: URL,
        progress: @escaping @Sendable (VideoImportPhase) async -> Void
    ) async throws -> VideoEvidence {
        await progress(.preparing)
        try Task.checkCancellation()

        await progress(.transcribing)
        var transcriptionUnavailable = false
        let transcript: String?
        do {
            transcript = try await transcriber.transcribe(url: url)
        } catch {
            transcriptionUnavailable = true
            transcript = nil
        }
        try Task.checkCancellation()

        await progress(.readingFrames)
        let frameEvidence = try? await frameReader.extractEvidence(from: url)
        try Task.checkCancellation()

        let evidence = VideoEvidence(
            transcript: transcript?.nilIfBlank,
            frameText: frameEvidence?.text.nilIfBlank,
            referenceImageURL: frameEvidence?.referenceImageURL
        )
        guard !evidence.isEmpty else {
            throw transcriptionUnavailable
                ? ImportError.transcriptionUnavailable
                : ImportError.noUsableContent
        }
        return evidence
    }
}

private actor LocalVideoTranscriber {
    func transcribe(url: URL) async throws -> String {
        guard await requestAuthorizationIfNeeded() else {
            throw ImportError.transcriptionUnavailable
        }
        guard SpeechTranscriber.isAvailable else {
            throw ImportError.transcriptionUnavailable
        }

        let requestedLocale = Locale(identifier: "it_IT")
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: requestedLocale) else {
            throw ImportError.transcriptionUnavailable
        }
        let installedLocales = await SpeechTranscriber.installedLocales
        guard installedLocales.contains(where: { $0.identifier == locale.identifier }) else {
            throw ImportError.transcriptionUnavailable
        }

        let preparedAudio = try await prepareAudioFile(from: url)
        defer {
            if let temporaryURL = preparedAudio.temporaryURL {
                try? FileManager.default.removeItem(at: temporaryURL)
            }
        }
        let audioFile = preparedAudio.file

        let transcriber = SpeechTranscriber(
            locale: locale,
            preset: .timeIndexedTranscriptionWithAlternatives
        )
        let analyzer = try await SpeechAnalyzer(
            inputAudioFile: audioFile,
            modules: [transcriber],
            finishAfterFile: true
        )

        let analysisTask = Task {
            try await analyzer.start(inputAudioFile: audioFile, finishAfterFile: true)
        }
        var segments: [String] = []
        do {
            for try await result in transcriber.results {
                try Task.checkCancellation()
                guard result.isFinal else { continue }
                let text = String(result.text.characters)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    segments.append(text)
                }
            }
            try await analysisTask.value
        } catch {
            analysisTask.cancel()
            throw ImportError.transcriptionUnavailable
        }

        let transcript = segments.joined(separator: "\n")
        guard !transcript.isEmpty else {
            throw ImportError.transcriptionUnavailable
        }
        return transcript
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        guard Bundle.main.object(
            forInfoDictionaryKey: "NSSpeechRecognitionUsageDescription"
        ) != nil else {
            return false
        }

        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func prepareAudioFile(
        from videoURL: URL
    ) async throws -> (file: AVAudioFile, temporaryURL: URL?) {
        if let directFile = try? AVAudioFile(forReading: videoURL) {
            return (directFile, nil)
        }

        let asset = AVURLAsset(url: videoURL)
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw ImportError.transcriptionUnavailable
        }
        let outputURL = FileManager.default.temporaryDirectory
            .appending(path: "\(UUID().uuidString).m4a")
        do {
            try await exportSession.export(to: outputURL, as: .m4a)
            return (try AVAudioFile(forReading: outputURL), outputURL)
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw ImportError.transcriptionUnavailable
        }
    }
}

private actor VideoFrameTextReader {
    func extractEvidence(from url: URL) async throws -> VideoFrameEvidence {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let seconds = duration.seconds
        guard seconds.isFinite, seconds > 0 else {
            throw ImportError.noUsableContent
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1_280, height: 1_280)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.25, preferredTimescale: 600)

        let times = sampleTimes(duration: seconds)
        var uniqueLines: [String] = []
        var normalizedLines = Set<String>()
        var referenceImageURL: URL?

        for time in times {
            try Task.checkCancellation()
            guard let image = try? await generator.image(at: time).image else { continue }
            if referenceImageURL == nil {
                referenceImageURL = try? RecipeArtworkStore.makeTemporaryImage(from: image)
            }
            for line in recognizeText(in: image) {
                let normalized = line
                    .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard normalized.count >= 2, normalizedLines.insert(normalized).inserted else {
                    continue
                }
                uniqueLines.append(line)
            }
        }

        let text = uniqueLines.joined(separator: "\n")
        guard !text.isEmpty || referenceImageURL != nil else {
            throw ImportError.noUsableContent
        }
        return VideoFrameEvidence(
            text: text,
            referenceImageURL: referenceImageURL
        )
    }

    private func sampleTimes(duration: Double) -> [CMTime] {
        let count = min(12, max(4, Int(ceil(duration / 6))))
        let inset = min(0.5, duration * 0.05)
        let usableDuration = max(0.1, duration - (inset * 2))
        return (0..<count).map { index in
            let progress = count == 1 ? 0.5 : Double(index) / Double(count - 1)
            return CMTime(
                seconds: inset + (usableDuration * progress),
                preferredTimescale: 600
            )
        }
    }

    private func recognizeText(in image: CGImage) -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["it-IT", "en-US"]
        request.minimumTextHeight = 0.018

        let handler = VNImageRequestHandler(cgImage: image)
        guard (try? handler.perform([request])) != nil else { return [] }
        return request.results?
            .compactMap { $0.topCandidates(1).first?.string }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            ?? []
    }
}

private struct VideoFrameEvidence: Sendable {
    let text: String
    let referenceImageURL: URL?
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
