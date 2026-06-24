import Foundation

actor WebRecipeFetcher {
    private let validator = SafeURLValidator()
    private let parser = RecipeJSONLDParser()
    private let maximumBytes = 5_000_000

    func fetch(_ rawURL: URL) async throws -> WebRecipeResult {
        let url = try validator.validate(rawURL)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 25
        configuration.httpAdditionalHeaders = [
            "Accept": "text/html,application/xhtml+xml,application/ld+json",
            "User-Agent": "DishD/1.0 (local recipe importer)"
        ]
        let session = URLSession(configuration: configuration)

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let finalURL = http.url
        else {
            throw ImportError.inaccessibleURL
        }
        _ = try validator.validate(finalURL)
        guard data.count <= maximumBytes else {
            throw ImportError.responseTooLarge
        }
        guard let mime = http.mimeType?.lowercased(),
              mime.contains("html") || mime.contains("json")
        else {
            throw ImportError.unsupportedContent
        }
        guard let html = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
        else {
            throw ImportError.noUsableContent
        }

        if let structured = parser.parse(html: html, sourceURL: finalURL) {
            return .structured(structured)
        }

        let readableText = HTMLTextExtractor().extract(from: html)
        guard readableText.count > 80 else {
            throw ImportError.noUsableContent
        }
        return .unstructured(
            text: String(readableText.prefix(30_000)),
            source: RecipeSourceDraft(
                title: HTMLTextExtractor().title(from: html),
                author: nil,
                url: finalURL,
                platform: finalURL.host ?? "web",
                attribution: finalURL.host,
                imageURL: HTMLTextExtractor().imageURL(from: html, relativeTo: finalURL)
            )
        )
    }
}

enum WebRecipeResult: Sendable {
    case structured(StructuredWebRecipe)
    case unstructured(text: String, source: RecipeSourceDraft)
}

struct StructuredWebRecipe: Sendable {
    let draft: RecipeDraft
    let evidence: RecipeEvidenceBundle
}

private struct HTMLTextExtractor {
    func title(from html: String) -> String? {
        capture(in: html, pattern: #"(?is)<title[^>]*>(.*?)</title>"#)
            .map(decode)
    }

    func extract(from html: String) -> String {
        var text = html
        text = text.replacingOccurrences(
            of: #"(?is)<(script|style|nav|footer|header|form)[^>]*>.*?</\1>"#,
            with: " ",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"(?i)<br\s*/?>|</p>|</li>|</h[1-6]>"#,
            with: "\n",
            options: .regularExpression
        )
        text = text.replacingOccurrences(of: #"(?s)<[^>]+>"#, with: " ", options: .regularExpression)
        return decode(text)
            .replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func imageURL(from html: String, relativeTo sourceURL: URL) -> URL? {
        let patterns = [
            #"(?is)<meta[^>]+property\s*=\s*["']og:image(?::secure_url)?["'][^>]+content\s*=\s*["']([^"']+)["']"#,
            #"(?is)<meta[^>]+content\s*=\s*["']([^"']+)["'][^>]+property\s*=\s*["']og:image(?::secure_url)?["']"#,
            #"(?is)<meta[^>]+name\s*=\s*["']twitter:image(?::src)?["'][^>]+content\s*=\s*["']([^"']+)["']"#
        ]
        for pattern in patterns {
            if let value = capture(in: html, pattern: pattern),
               let url = URL(string: decode(value), relativeTo: sourceURL)?.absoluteURL {
                return url
            }
        }
        return nil
    }

    private func capture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return String(text[range])
    }

    private func decode(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}
