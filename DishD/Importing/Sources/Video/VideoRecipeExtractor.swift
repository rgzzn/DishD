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
        let cleanContext = context?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfBlank

        // When the caption / description is substantial (≥80 chars) it likely
        // contains the actual recipe text (ingredients, steps). Put it first so
        // the extraction model treats it as the primary source and uses frame OCR
        // / transcript only as supplementary evidence.
        let captionIsSubstantial = (cleanContext?.count ?? 0) >= 80
        var parts: [String] = []

        if captionIsSubstantial {
            parts.append("[Descrizione e ingredienti]\n\(cleanContext!)")
            if let frameText = frameText, !frameText.isEmpty {
                parts.append("[Testo letto nei fotogrammi]\n\(frameText)")
            }
            if let transcript = transcript, !transcript.isEmpty {
                parts.append("[Trascrizione audio]\n\(transcript)")
            }
        } else {
            if let frameText = frameText, !frameText.isEmpty {
                parts.append("[Testo letto nei fotogrammi]\n\(frameText)")
            }
            if let transcript = transcript, !transcript.isEmpty {
                parts.append("[Trascrizione audio]\n\(transcript)")
            }
            if let cleanContext {
                parts.append("[Didascalia, nota o link condiviso]\n\(cleanContext)")
            }
        }

        return parts.joined(separator: "\n\n")
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
        // Audio is best-effort: a nil transcript still lets us proceed on frame text.
        let transcript = await transcriber.transcribe(url: url)
        try Task.checkCancellation()

        await progress(.readingFrames)
        let frameEvidence = try? await frameReader.extractEvidence(from: url)
        try Task.checkCancellation()

        let evidence = VideoEvidence(
            transcript: transcript?.nilIfBlank,
            frameText: frameEvidence?.text.nilIfBlank,
            referenceImageURL: frameEvidence?.referenceImageURL
        )
        // Only fail when the video yielded nothing at all — frames or a reference image
        // alone are enough to keep going (the caption path can supply the rest).
        guard !evidence.isEmpty || evidence.referenceImageURL != nil else {
            throw ImportError.noUsableContent
        }
        return evidence
    }
}

private actor LocalVideoTranscriber {
    /// Transcribes the video's audio entirely on-device. Returns nil (never throws) when
    /// no local engine is available so the pipeline can still proceed on frame text.
    func transcribe(url: URL) async -> String? {
        guard await requestAuthorizationIfNeeded() else { return nil }

        // Prefer the modern SpeechAnalyzer stack; fall back to SFSpeechRecognizer, which
        // is available on more devices/locales (and on Simulator) than SpeechTranscriber.
        if let viaAnalyzer = try? await transcribeWithSpeechAnalyzer(url: url),
           let transcript = viaAnalyzer.nilIfBlank {
            return transcript
        }
        return await transcribeWithSFSpeech(url: url)
    }

    private func transcribeWithSpeechAnalyzer(url: URL) async throws -> String {
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

    /// On-device transcription via the long-standing SFSpeechRecognizer. To preserve the
    /// app's local-first privacy promise we ONLY proceed when on-device recognition is
    /// supported and force `requiresOnDeviceRecognition`, so audio is never sent to a server.
    private func transcribeWithSFSpeech(url: URL) async -> String? {
        let candidateLocales = [
            Locale(identifier: "it_IT"),
            Locale(identifier: "en_US"),
            Locale.current
        ]
        for locale in candidateLocales {
            guard let recognizer = SFSpeechRecognizer(locale: locale),
                  recognizer.isAvailable,
                  recognizer.supportsOnDeviceRecognition
            else {
                continue
            }
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.requiresOnDeviceRecognition = true
            request.addsPunctuation = true
            if let transcript = (try? await recognize(request, with: recognizer))?.nilIfBlank {
                return transcript
            }
        }
        return nil
    }

    private func recognize(
        _ request: SFSpeechURLRecognitionRequest,
        with recognizer: SFSpeechRecognizer
    ) async throws -> String {
        let state = RecognitionResumeState()
        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    state.finishOnce { continuation.resume(throwing: error) }
                    return
                }
                guard let result, result.isFinal else { return }
                let text = result.bestTranscription.formattedString
                state.finishOnce { continuation.resume(returning: text) }
            }
        }
    }
}

/// Guards a checked continuation so it resumes exactly once even though the speech
/// recognition handler may fire multiple times.
private final class RecognitionResumeState: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false

    func finishOnce(_ resume: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return }
        finished = true
        resume()
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
        // Larger frames + a lower minimum text height (see recognizeText) capture the small,
        // briefly-flashed ingredient/measurement overlays common in recipe Reels/TikToks.
        generator.maximumSize = CGSize(width: 1_600, height: 1_600)
        // A small symmetric tolerance keeps seeks fast enough to afford denser sampling.
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.3, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.3, preferredTimescale: 600)

        let hardFrameCap = 16
        var uniqueLines: [String] = []
        var normalizedLines = Set<String>()
        var referenceImageURL: URL?
        var sampledSeconds: [Double] = []

        // Synchronous dedup of a frame's recognized lines; returns how many NEW lines it
        // contributed (its "text density"), which drives the adaptive refinement pass.
        func ingest(_ lines: [String]) -> Int {
            var added = 0
            for line in lines {
                let normalized = Self.normalize(line)
                guard normalized.count >= 2, normalizedLines.insert(normalized).inserted else {
                    continue
                }
                uniqueLines.append(line)
                added += 1
            }
            return added
        }

        // Pass A — a coarse, evenly-spaced sweep that scores where on-screen text lives.
        var densities: [(time: Double, density: Int)] = []
        for second in coarseSampleSeconds(duration: seconds) {
            try Task.checkCancellation()
            let time = CMTime(seconds: second, preferredTimescale: 600)
            guard let image = try? await generator.image(at: time).image else {
                densities.append((second, 0))
                continue
            }
            if referenceImageURL == nil {
                referenceImageURL = try? RecipeArtworkStore.makeTemporaryImage(from: image)
            }
            sampledSeconds.append(second)
            densities.append((second, ingest(recognizeText(in: image))))
        }

        // Pass B — refine around the text-densest frames to catch overlays that render a
        // beat before/after the sampled instant, without re-decoding the coarse frames.
        let inset = min(0.5, seconds * 0.05)
        let densest = densities
            .filter { $0.density > 0 }
            .sorted { $0.density > $1.density }
            .prefix(3)
        for entry in densest {
            for delta in [-1.5, 1.5] where sampledSeconds.count < hardFrameCap {
                let neighbor = min(max(entry.time + delta, inset), max(inset, seconds - inset))
                guard !sampledSeconds.contains(where: { abs($0 - neighbor) < 0.75 }) else { continue }
                try Task.checkCancellation()
                let time = CMTime(seconds: neighbor, preferredTimescale: 600)
                guard let image = try? await generator.image(at: time).image else { continue }
                sampledSeconds.append(neighbor)
                _ = ingest(recognizeText(in: image))
            }
        }

        let text = uniqueLines.joined(separator: "\n")
        // Require either a meaningful amount of text or at least 2 frames worth of content.
        // A single frame with a few characters is likely just a title card or watermark,
        // not enough to extract a recipe — let the caller fall back to caption text.
        let hasMeaningfulText = text.count >= 40 || uniqueLines.count >= 2
        guard hasMeaningfulText || referenceImageURL != nil else {
            throw ImportError.noUsableContent
        }
        if !hasMeaningfulText {
            // We only have a reference image with no useful text. Signal that the caller
            // should prefer caption extraction, but keep the image for the draft cover.
            return VideoFrameEvidence(text: "", referenceImageURL: referenceImageURL)
        }
        return VideoFrameEvidence(
            text: text,
            referenceImageURL: referenceImageURL
        )
    }

    private func coarseSampleSeconds(duration: Double) -> [Double] {
        let count = min(8, max(4, Int(ceil(duration / 6))))
        let inset = min(0.5, duration * 0.05)
        let usableDuration = max(0.1, duration - (inset * 2))
        return (0..<count).map { index in
            let progress = count == 1 ? 0.5 : Double(index) / Double(count - 1)
            return inset + (usableDuration * progress)
        }
    }

    private static func normalize(_ line: String) -> String {
        line
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func recognizeText(in image: CGImage) -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["it-IT", "en-US"]
        // Lower than the default so small flashing overlays (quantities, temperatures)
        // are not discarded as noise.
        request.minimumTextHeight = 0.01

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
