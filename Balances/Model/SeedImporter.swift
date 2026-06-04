import CoreData

/// Seeds the store from bundled JSON on first launch.
enum SeedImporter {
    private static let seededKey = "didSeedInitialData_v1"

    private struct BalanceSeed: Decodable {
        let date: String
        let balance: Double
        let adjustment: Double
        let transfers: Double?
        let note: String?
    }

    private struct TSXSeed: Decodable {
        let sortOrder: Int
        let year: Int?
        let label: String?
        let tsxReturn: Double
        let netCashFlows: Double
        let actualStart: Double
        let actualEnd: Double
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func seedIfNeeded(context: NSManagedObjectContext) {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: seededKey) { return }

        // Guard against double-seeding an already-populated store.
        let count = (try? context.count(for: BalanceEntry.fetchRequest())) ?? 0
        if count == 0 {
            seedBalances(context: context)
            seedTSX(context: context)
            do { try context.save() } catch { NSLog("Seed save failed: \(error)") }
        }
        defaults.set(true, forKey: seededKey)
    }

    private static func seedBalances(context: NSManagedObjectContext) {
        guard let url = Bundle.main.url(forResource: "balances_seed", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let rows = try? JSONDecoder().decode([BalanceSeed].self, from: data) else {
            NSLog("balances_seed.json missing or invalid")
            return
        }
        for r in rows {
            guard let date = dateFormatter.date(from: r.date) else { continue }
            let e = BalanceEntry(context: context)
            e.id = UUID()
            e.date = date
            e.balance = r.balance
            e.adjustment = r.adjustment
            e.transfers = r.transfers ?? 0
            e.note = r.note
        }
    }

    private static func seedTSX(context: NSManagedObjectContext) {
        guard let url = Bundle.main.url(forResource: "tsx_seed", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let rows = try? JSONDecoder().decode([TSXSeed].self, from: data) else {
            NSLog("tsx_seed.json missing or invalid")
            return
        }
        for r in rows {
            let y = TSXYear(context: context)
            y.id = UUID()
            y.sortOrder = Int16(r.sortOrder)
            y.year = Int32(r.year ?? 0)
            y.label = r.label
            y.tsxReturn = r.tsxReturn
            y.netCashFlows = r.netCashFlows
            y.actualStart = r.actualStart
            y.actualEnd = r.actualEnd
        }
    }
}
