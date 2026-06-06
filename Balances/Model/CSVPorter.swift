import AppKit
import CoreData
import UniformTypeIdentifiers

/// CSV import/export for the balances table.
/// Columns: Date,Balance,Adjustment,Transfers,Note
enum CSVPorter {

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Date formats accepted on import, tried in order (ISO first, then the
    /// common North-American slash forms, then a couple of spelled-out ones).
    private static let importDateFormatters: [DateFormatter] = {
        ["yyyy-MM-dd", "yyyy/MM/dd", "MM/dd/yyyy", "M/d/yyyy",
         "yyyy-MM-dd'T'HH:mm:ss", "MMM d, yyyy", "d MMM yyyy", "MMMM d, yyyy"]
            .map { fmt in
                let f = DateFormatter()
                f.calendar = Calendar(identifier: .gregorian)
                f.locale = Locale(identifier: "en_US_POSIX")
                f.dateFormat = fmt
                return f
            }
    }()

    private static func parseDate(_ s: String) -> Date? {
        let t = s.trimmingCharacters(in: .whitespaces)
        for f in importDateFormatters where f.date(from: t) != nil {
            return f.date(from: t)
        }
        return nil
    }

    /// Parses a number tolerating "$", thousands commas, surrounding spaces,
    /// and accounting-style negatives like "(1,234)".
    private static func parseNumber(_ s: String) -> Double? {
        var t = s.trimmingCharacters(in: .whitespaces)
        var negate = false
        if t.hasPrefix("(") && t.hasSuffix(")") {
            negate = true
            t = String(t.dropFirst().dropLast())
        }
        t = t.replacingOccurrences(of: "$", with: "")
             .replacingOccurrences(of: ",", with: "")
             .replacingOccurrences(of: " ", with: "")
        guard let v = Double(t) else { return nil }
        return negate ? -v : v
    }

    // MARK: Export

    static func csvString(for entries: [BalanceEntry]) -> String {
        var lines = ["Date,Balance,Adjustment,Transfers,Note"]
        let sorted = entries.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        for e in sorted {
            let date = dateFormatter.string(from: e.date ?? Date())
            let fields = [
                date,
                String(e.balance),
                String(e.adjustment),
                e.transfers == 0 ? "" : String(e.transfers),
                escape(e.note ?? "")
            ]
            lines.append(fields.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    static func export(_ entries: [BalanceEntry]) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "balances.csv"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try csvString(for: entries).write(to: url, atomically: true, encoding: .utf8)
        } catch {
            presentError("Could not export CSV: \(error.localizedDescription)")
        }
    }

    private static func escape(_ s: String) -> String {
        guard s.contains(",") || s.contains("\"") || s.contains("\n") else { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: Import

    /// Presents an open panel and imports rows into the context.
    /// Returns the number of imported rows, or nil if cancelled.
    @discardableResult
    static func importCSV(into context: NSManagedObjectContext) -> Int? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .text]
        panel.allowsMultipleSelection = false
        panel.message = "Choose a CSV with columns: Date, Balance, Adjustment, Transfers, Note"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            presentError("Could not read file.")
            return nil
        }
        var imported = 0
        var skipped = 0
        let rows = parse(text)
        for (i, cols) in rows.enumerated() {
            // Skip a header row if present.
            if i == 0, cols.first?.lowercased().contains("date") == true { continue }
            // Ignore fully blank lines.
            guard cols.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else { continue }
            guard cols.count >= 2,
                  let date = parseDate(cols[0]),
                  let balance = parseNumber(cols[1]) else {
                skipped += 1
                continue
            }
            let e = BalanceEntry(context: context)
            e.id = UUID()
            e.date = date
            e.balance = balance
            e.adjustment = cols.count > 2 ? (parseNumber(cols[2]) ?? 0) : 0
            e.transfers = cols.count > 3 ? (parseNumber(cols[3]) ?? 0) : 0
            e.note = cols.count > 4 ? unescape(cols[4]) : nil
            imported += 1
        }
        if imported > 0 {
            do { try context.save() }
            catch {
                presentError("Save failed: \(error.localizedDescription)")
                return imported
            }
        }
        presentResult(imported: imported, skipped: skipped)
        return imported
    }

    /// Minimal CSV parser supporting quoted fields and escaped quotes.
    private static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var field = ""
        var record: [String] = []
        var inQuotes = false
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" {
                        field.append("\""); i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(c)
                }
            } else {
                switch c {
                case "\"": inQuotes = true
                case ",": record.append(field); field = ""
                case "\n", "\r":
                    if c == "\r", i + 1 < chars.count, chars[i + 1] == "\n" { i += 1 }
                    record.append(field); field = ""
                    if !(record.count == 1 && record[0].isEmpty) { rows.append(record) }
                    record = []
                default: field.append(c)
                }
            }
            i += 1
        }
        if !field.isEmpty || !record.isEmpty {
            record.append(field)
            rows.append(record)
        }
        return rows
    }

    private static func unescape(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : t
    }

    private static func presentResult(imported: Int, skipped: Int) {
        let alert = NSAlert()
        if imported == 0 {
            alert.alertStyle = .warning
            alert.messageText = "No rows imported"
            alert.informativeText = "Expected columns: Date, Balance, Adjustment, Transfers, Note. "
                + "Dates such as 2026-06-04 or 06/04/2026 are accepted."
                + (skipped > 0 ? "\n\n\(skipped) row(s) couldn't be parsed." : "")
        } else {
            alert.alertStyle = .informational
            alert.messageText = "Imported \(imported) \(imported == 1 ? "entry" : "entries")"
            if skipped > 0 {
                alert.informativeText = "\(skipped) row(s) were skipped (couldn't be parsed)."
            }
        }
        alert.runModal()
    }

    private static func presentError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "CSV Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
