import Foundation

enum DecimalParser {
    private static let vulgar: [Character: Decimal] = ["½": 0.5, "⅓": Decimal(1)/Decimal(3), "⅔": Decimal(2)/Decimal(3), "¼": 0.25, "¾": 0.75, "⅛": 0.125]
    static func parse(_ text: String?) -> Decimal? {
        guard var value = text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !value.isEmpty else { return nil }
        if ["q.b.", "qb", "quanto basta", "a piacere", "una manciata"].contains(value) { return nil }
        value = value.replacingOccurrences(of: ",", with: ".")
        if let first = value.first, let number = vulgar[first] { return number }
        let parts = value.split(separator: " ")
        if parts.count == 2, let whole = Decimal(string: String(parts[0])), let fraction = parseFraction(String(parts[1])) { return whole + fraction }
        if let fraction = parseFraction(value) { return fraction }
        return Decimal(string: value)
    }
    private static func parseFraction(_ text: String) -> Decimal? {
        let p = text.split(separator: "/")
        guard p.count == 2, let n = Decimal(string: String(p[0])), let d = Decimal(string: String(p[1])), d != 0 else { return nil }
        return n / d
    }
}
