import Foundation

enum Fmt {
    static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        f.currencyCode = "CAD"
        f.currencySymbol = "$"
        return f
    }()

    static let currencyCents: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 2
        f.currencyCode = "CAD"
        f.currencySymbol = "$"
        return f
    }()

    static let percent: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .percent
        f.maximumFractionDigits = 1
        return f
    }()

    static let date: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    /// Canonical "yyyy-MM-dd" formatter for typed date entry.
    static let isoDay: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func parseDay(_ s: String) -> Date? {
        isoDay.date(from: s.trimmingCharacters(in: .whitespaces))
    }

    /// Parses plain numeric text-field input, rejecting blanks and non-finite values
    /// (`Double()` otherwise accepts "nan"/"inf", which poison every downstream stat).
    static func finiteNumber(_ s: String) -> Double? {
        guard let v = Double(s.trimmingCharacters(in: .whitespaces)), v.isFinite else { return nil }
        return v
    }

    static func isoString(_ d: Date) -> String {
        isoDay.string(from: d)
    }

    static func money(_ v: Double) -> String {
        currency.string(from: NSNumber(value: v)) ?? "$0"
    }

    static func moneyCents(_ v: Double) -> String {
        currencyCents.string(from: NSNumber(value: v)) ?? "$0.00"
    }

    static func pct(_ v: Double) -> String {
        percent.string(from: NSNumber(value: v)) ?? "0%"
    }

    static func day(_ d: Date) -> String {
        date.string(from: d)
    }
}
