import Foundation

enum DecimalParser {
    private static let vulgarFractions: [Character: Decimal] = [
        "½": Decimal(1) / Decimal(2),
        "⅓": Decimal(1) / Decimal(3),
        "⅔": Decimal(2) / Decimal(3),
        "¼": Decimal(1) / Decimal(4),
        "¾": Decimal(3) / Decimal(4),
        "⅛": Decimal(1) / Decimal(8)
    ]

    static func parse(_ text: String?) -> Decimal? {
        guard var value = text?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
            !value.isEmpty
        else {
            return nil
        }

        if ["q.b.", "qb", "quanto basta", "a piacere", "una manciata", "un pizzico"].contains(value) {
            return nil
        }

        value = value.replacingOccurrences(of: ",", with: ".")
        if let single = value.first, value.count == 1, let fraction = vulgarFractions[single] {
            return fraction
        }

        for (character, fraction) in vulgarFractions where value.last == character {
            let wholeText = String(value.dropLast()).trimmingCharacters(in: .whitespaces)
            return (Decimal(string: wholeText) ?? 0) + fraction
        }

        let parts = value.split(separator: " ")
        if parts.count == 2,
           let whole = Decimal(string: String(parts[0])),
           let fraction = parseFraction(String(parts[1])) {
            return whole + fraction
        }

        return parseFraction(value) ?? Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
    }

    static func parseRange(_ text: String?) -> (minimum: Decimal?, maximum: Decimal?) {
        guard let text else { return (nil, nil) }
        let parts = text
            .replacingOccurrences(of: "—", with: "–")
            .split(separator: "–", maxSplits: 1)
            .map(String.init)
        if parts.count == 2 {
            return (parse(parts[0]), parse(parts[1]))
        }
        let value = parse(text)
        return (value, nil)
    }

    private static func parseFraction(_ text: String) -> Decimal? {
        let parts = text.split(separator: "/")
        guard parts.count == 2,
              let numerator = Decimal(string: String(parts[0])),
              let denominator = Decimal(string: String(parts[1])),
              denominator != 0
        else {
            return nil
        }
        return numerator / denominator
    }
}
