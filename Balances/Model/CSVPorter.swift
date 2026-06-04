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
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            presentError("Could not read file.")
            return nil
        }
        var imported = 0
        let rows = parse(text)
        for (i, cols) in rows.enumerated() {
            // Skip header row if present.
            if i == 0, cols.first?.lowercased() == "date" { continue }
            guard cols.count >= 2 else { continue }
            guard let date = dateFormatter.date(from: cols[0].trimmingCharacters(in: .whitespaces)),
                  let balance = Double(cols[1].trimmingCharacters(in: .whitespaces)) else { continue }
            let e = BalanceEntry(context: context)
            e.id = UUID()
            e.date = date
            e.balance = balance
            e.adjustment = cols.count > 2 ? (Double(cols[2].trimmingCharacters(in: .whitespaces)) ?? 0) : 0
            e.transfers = cols.count > 3 ? (Double(cols[3].trimmingCharacters(in: .whitespaces)) ?? 0) : 0
            e.note = cols.count > 4 ? unescape(cols[4]) : nil
            imported += 1
        }
        do { try context.save() } catch { presentError("Save failed: \(error.localizedDescription)") }
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

    private static func presentError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "CSV Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
