import Foundation
@preconcurrency import LinkPresentation

struct SocialPostFetcher: Sendable {
    private let validator = SafeURLValidator()
    private let maximumBytes = 5_000_000

    func fetch(_ rawURL: URL) async throws -> SocialPostResult {
        let url = try validator.validate(rawURL)
        guard let platform = SocialPlatform(url: url) else {
            throw ImportError.unsupportedContent
        }

        let linkMetadata = try? await fetchLinkMetadata(for: url)
        let oEmbed = try? await fetchOEmbed(for: url, platform: platform)
        let metadata = try? await fetchPublicMetadata(for: url)
        let text = combinedText(
            platform: platform,
            linkMetadata: linkMetadata,
            oEmbed: oEmbed,
            metadata: metadata
        )

        guard text.trimmingCharacters(in: .whitespacesAndNewlines).count > 20 else {
            throw ImportError.socialContentUnavailable
        }

        return SocialPostResult(
            text: text,
            source: RecipeSourceDraft(
                title: cleanTitle(oEmbed?.title ?? linkMetadata?.title ?? metadata?.title),
                author: oEmbed?.authorName,
                url: metadata?.url ?? linkMetadata?.originalURL ?? linkMetadata?.url ?? url,
                platform: platform.displayName,
                attribution: oEmbed?.authorName ?? (metadata?.url ?? url).host,
                imageURL: oEmbed?.thumbnailURL ?? metadata?.imageURL
            ),
            remoteVideoURL: linkMetadata?.remoteVideoURL.flatMap(supportedRemoteVideoURL)
        )
    }

    static func platformName(for url: URL) -> String? {
        SocialPlatform(url: url)?.displayName
    }

    @MainActor
    private func fetchLinkMetadata(for url: URL) async throws -> SocialLinkMetadata {
        try await withCheckedThrowingContinuation { continuation in
            let provider = LPMetadataProvider()
            provider.timeout = 12
            provider.startFetchingMetadata(for: url) { metadata, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let metadata else {
                    continuation.resume(throwing: ImportError.noUsableContent)
                    return
                }
                let result = SocialLinkMetadata(
                    title: metadata.title,
                    url: metadata.url,
                    originalURL: metadata.originalURL,
                    remoteVideoURL: metadata.remoteVideoURL
                )
                continuation.resume(returning: result)
            }
        }
    }

    private func fetchOEmbed(
        for url: URL,
        platform: SocialPlatform
    ) async throws -> SocialOEmbedResponse {
        guard let endpoint = platform.oEmbedEndpoint(for: url) else {
            throw ImportError.unsupportedContent
        }

        var request = URLRequest(url: endpoint)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("DishD/1.0 (social recipe importer)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await makeSession().data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              data.count <= maximumBytes
        else {
            throw ImportError.inaccessibleURL
        }
        return try JSONDecoder().decode(SocialOEmbedResponse.self, from: data)
    }

    private func fetchPublicMetadata(for url: URL) async throws -> SocialPageMetadata {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await makeSession().data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let finalURL = http.url,
              data.count <= maximumBytes
        else {
            throw ImportError.inaccessibleURL
        }
        _ = try validator.validate(finalURL)
        guard let mime = http.mimeType?.lowercased(),
              mime.contains("html"),
              let html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
        else {
            throw ImportError.unsupportedContent
        }
        return SocialHTMLMetadataExtractor().metadata(from: html, url: finalURL)
    }

    private func combinedText(
        platform: SocialPlatform,
        linkMetadata: SocialLinkMetadata?,
        oEmbed: SocialOEmbedResponse?,
        metadata: SocialPageMetadata?
    ) -> String {
        var candidates: [String?] = []
        candidates.append(linkMetadata?.title)
        candidates.append(oEmbed?.title)
        candidates.append(oEmbed?.html.flatMap { SocialHTMLMetadataExtractor().caption(fromEmbedHTML: $0, platform: platform) })
        candidates.append(metadata?.description)
        candidates.append(contentsOf: metadata?.captions ?? [])
        candidates.append(metadata?.title)
        candidates.append(oEmbed?.html.map { SocialHTMLMetadataExtractor().plainText(from: $0) })

        let cleaned = candidates
            .compactMap { $0 }
            .map { cleanSocialText($0, platform: platform) }
            .filter { !$0.isEmpty && !platform.ignoredText.contains($0.lowercased()) }

        return deduplicated(cleaned)
            .prefix(8)
            .joined(separator: "\n\n")
    }

    private func cleanSocialText(_ value: String, platform: SocialPlatform) -> String {
        var text = value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if platform == .instagram {
            text = cleanInstagramDescription(text)
        }
        return text
    }

    private func cleanInstagramDescription(_ value: String) -> String {
        let marker = " on Instagram: "
        guard let range = value.range(of: marker, options: .caseInsensitive) else {
            return value
        }
        let caption = value[range.upperBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"“”"))
        return String(caption)
    }

    private func cleanTitle(_ value: String?) -> String? {
        value?
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfBlank
    }

    private func deduplicated(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0.lowercased()).inserted }
    }

    private func supportedRemoteVideoURL(_ url: URL) -> URL? {
        guard url.scheme?.lowercased() == "https" else { return nil }
        let extensionHint = url.pathExtension.lowercased()
        if ["mov", "mp4", "m4v", "m3u8"].contains(extensionHint) {
            return url
        }
        let absolute = url.absoluteString.lowercased()
        guard absolute.contains(".mp4")
            || absolute.contains(".mov")
            || absolute.contains(".m4v")
            || absolute.contains(".m3u8")
        else {
            return nil
        }
        return url
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 18
        return URLSession(configuration: configuration)
    }
}

struct SocialPostResult: Sendable {
    let text: String
    let source: RecipeSourceDraft
    let remoteVideoURL: URL?

    func combinedText(with context: String?) -> String {
        [text, context?.nilIfBlank]
            .compactMap { $0 }
            .joined(separator: "\n\n")
    }
}

private struct SocialLinkMetadata: Sendable {
    let title: String?
    let url: URL?
    let originalURL: URL?
    let remoteVideoURL: URL?
}

private enum SocialPlatform: Equatable {
    case instagram
    case tiktok

    init?(url: URL) {
        guard let host = url.host?.lowercased() else { return nil }
        if host == "instagram.com" || host.hasSuffix(".instagram.com") {
            self = .instagram
        } else if host == "tiktok.com" || host.hasSuffix(".tiktok.com") {
            self = .tiktok
        } else {
            return nil
        }
    }

    var displayName: String {
        switch self {
        case .instagram: "Instagram"
        case .tiktok: "TikTok"
        }
    }

    var ignoredText: Set<String> {
        switch self {
        case .instagram:
            ["view this post on instagram"]
        case .tiktok:
            []
        }
    }

    func oEmbedEndpoint(for url: URL) -> URL? {
        var components: URLComponents
        switch self {
        case .instagram:
            components = URLComponents(string: "https://graph.facebook.com/instagram_oembed")!
        case .tiktok:
            components = URLComponents(string: "https://www.tiktok.com/oembed")!
        }
        components.queryItems = [
            URLQueryItem(name: "url", value: url.absoluteString)
        ]
        return components.url
    }
}

private struct SocialOEmbedResponse: Decodable, Sendable {
    let title: String?
    let authorName: String?
    let html: String?
    private let thumbnailURLString: String?

    var thumbnailURL: URL? {
        thumbnailURLString.flatMap(URL.init(string:))
    }

    enum CodingKeys: String, CodingKey {
        case title
        case authorName = "author_name"
        case html
        case thumbnailURLString = "thumbnail_url"
    }
}

private struct SocialPageMetadata: Sendable {
    let title: String?
    let description: String?
    let captions: [String]
    let imageURL: URL?
    let url: URL
}

private struct SocialHTMLMetadataExtractor {
    func metadata(from html: String, url: URL) -> SocialPageMetadata {
        SocialPageMetadata(
            title: firstMetaValue(["og:title", "twitter:title"], in: html) ?? title(from: html),
            description: firstMetaValue(["og:description", "description", "twitter:description"], in: html),
            captions: captionCandidates(from: html),
            imageURL: firstMetaValue(["og:image:secure_url", "og:image", "twitter:image", "twitter:image:src"], in: html)
                .flatMap { URL(string: $0, relativeTo: url)?.absoluteURL },
            url: url
        )
    }

    func caption(fromEmbedHTML html: String, platform: SocialPlatform) -> String? {
        switch platform {
        case .instagram:
            return nil
        case .tiktok:
            return capture(in: html, pattern: #"(?is)<p[^>]*>(.*?)</p>"#)
                .map(plainText)?
                .nilIfBlank
        }
    }

    func plainText(from html: String) -> String {
        var text = html
        text = text.replacingOccurrences(
            of: #"(?is)<(script|style|svg)[^>]*>.*?</\1>"#,
            with: " ",
            options: .regularExpression
        )
        text = text.replacingOccurrences(of: #"(?i)<br\s*/?>|</p>|</a>|</div>"#, with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?s)<[^>]+>"#, with: " ", options: .regularExpression)
        return decode(text)
            .replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func captionCandidates(from html: String) -> [String] {
        let patterns = [
            #""caption"\s*:\s*\{[^{}]*"text"\s*:\s*"((?:\\.|[^"\\])*)""#,
            #""edge_media_to_caption"\s*:\s*\{(?s:.*?)"text"\s*:\s*"((?:\\.|[^"\\])*)""#,
            #""video_description"\s*:\s*"((?:\\.|[^"\\])*)""#,
            #""desc"\s*:\s*"((?:\\.|[^"\\])*)""#
        ]
        var values: [String] = []
        var seen = Set<String>()
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            for match in matches {
                guard match.numberOfRanges > 1,
                      let range = Range(match.range(at: 1), in: html),
                      let decoded = decodeJSONString(String(html[range]))?.nilIfBlank
                else {
                    continue
                }
                let cleaned = decoded
                    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if seen.insert(cleaned.lowercased()).inserted {
                    values.append(cleaned)
                }
            }
        }
        return values
    }

    private func title(from html: String) -> String? {
        capture(in: html, pattern: #"(?is)<title[^>]*>(.*?)</title>"#)
            .map(decode)?
            .nilIfBlank
    }

    private func firstMetaValue(_ names: [String], in html: String) -> String? {
        for name in names {
            let escaped = NSRegularExpression.escapedPattern(for: name)
            let patterns = [
                #"(?is)<meta[^>]+property\s*=\s*["']\#(escaped)["'][^>]+content\s*=\s*["']([^"']+)["']"#,
                #"(?is)<meta[^>]+name\s*=\s*["']\#(escaped)["'][^>]+content\s*=\s*["']([^"']+)["']"#,
                #"(?is)<meta[^>]+content\s*=\s*["']([^"']+)["'][^>]+property\s*=\s*["']\#(escaped)["']"#,
                #"(?is)<meta[^>]+content\s*=\s*["']([^"']+)["'][^>]+name\s*=\s*["']\#(escaped)["']"#
            ]
            for pattern in patterns {
                if let value = capture(in: html, pattern: pattern)?.nilIfBlank {
                    return decode(value)
                }
            }
        }
        return nil
    }

    private func capture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return String(text[range])
    }

    private func decode(_ value: String) -> String {
        decodeNumericEntities(
            value
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#39;", with: "'")
                .replacingOccurrences(of: "&apos;", with: "'")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
        )
    }

    private func decodeJSONString(_ value: String) -> String? {
        let wrapped = "\"\(value)\""
        guard let data = wrapped.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(String.self, from: data)
    }

    private func decodeNumericEntities(_ value: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"&#(x?[0-9A-Fa-f]+);"#) else {
            return value
        }
        var result = value
        let matches = regex.matches(in: value, range: NSRange(value.startIndex..., in: value))
        for match in matches.reversed() {
            guard let fullRange = Range(match.range(at: 0), in: result),
                  let numberRange = Range(match.range(at: 1), in: result)
            else { continue }
            let raw = String(result[numberRange])
            let radix = raw.lowercased().hasPrefix("x") ? 16 : 10
            let digits = radix == 16 ? String(raw.dropFirst()) : raw
            guard let value = UInt32(digits, radix: radix),
                  let scalar = UnicodeScalar(value)
            else { continue }
            result.replaceSubrange(fullRange, with: String(Character(scalar)))
        }
        return result
    }
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
