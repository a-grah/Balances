import AppKit
import CoreData

/// AppleScript support (see Balances.sdef).
///
/// The application object is the scripting container: it exposes the
/// `balance entries` and `tsx years` element collections plus a handful of
/// read-only portfolio-summary properties. Scripts can read everything and
/// create new balance entries with `make new balance entry`; editing and
/// deleting existing entries is intentionally not exposed.
extension NSApplication {

    private var viewContext: NSManagedObjectContext {
        PersistenceController.shared.container.viewContext
    }

    // MARK: Elements

    @objc var balanceEntries: [BalanceEntry] {
        let request = BalanceEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \BalanceEntry.date, ascending: true)]
        return (try? viewContext.fetch(request)) ?? []
    }

    @objc var tsxYears: [TSXYear] {
        let request = TSXYear.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TSXYear.sortOrder, ascending: true)]
        return (try? viewContext.fetch(request)) ?? []
    }

    /// Fast unique-ID lookups, used by Cocoa Scripting to resolve
    /// `balance entry id "..."` / `tsx year id "..."` specifiers.
    @objc func valueInBalanceEntries(withUniqueID uniqueID: String) -> BalanceEntry? {
        balanceEntries.first { $0.scriptID == uniqueID }
    }

    @objc func valueInTsxYears(withUniqueID uniqueID: String) -> TSXYear? {
        tsxYears.first { $0.scriptID == uniqueID }
    }

    // Indexed-accessor pattern for the to-many relationships, required by
    // Cocoa Scripting to resolve ordinal/index specifiers ("first balance
    // entry", "balance entry 3", "last tsx year", etc.); plain array-valued
    // properties only satisfy "every"/"count".
    @objc func countOfBalanceEntries() -> Int { balanceEntries.count }
    @objc func objectInBalanceEntriesAtIndex(_ index: Int) -> BalanceEntry { balanceEntries[index] }
    @objc func countOfTsxYears() -> Int { tsxYears.count }
    @objc func objectInTsxYearsAtIndex(_ index: Int) -> TSXYear { tsxYears[index] }

    // KVC requires a remove accessor to exist for `balanceEntries` to be seen
    // as a mutable to-many relationship (needed for `make new balance entry`
    // to construct its insertion proxy), even though scripted deletion is not
    // supported and this is never expected to be called.
    @objc func removeObjectFromBalanceEntriesAtIndex(_ index: Int) {}

    // MARK: Portfolio summary properties

    private var summary: PortfolioSummary {
        PortfolioStats.summary(balanceEntries.statsInputs)
    }

    @objc var entryCount: Int { balanceEntries.count }
    @objc var startingBalance: Double { summary.startingBalance }
    @objc var currentValue: Double { summary.currentValue }
    @objc var netCashFlows: Double { summary.netCashFlows }
    @objc var investmentGain: Double { summary.investmentGain }
    @objc var gainPercent: Double { summary.gainPercent }
    @objc var maximumBalance: Double { PortfolioStats.maxBalance(balanceEntries.statsInputs) }
    @objc var totalDeposits: Double { PortfolioStats.totalDeposits(balanceEntries.statsInputs) }
    @objc var totalWithdrawals: Double { PortfolioStats.totalWithdrawals(balanceEntries.statsInputs) }

    // MARK: Creation ("make new balance entry ...")

    /// Creates a new `BalanceEntry`, inserted into the shared view context and
    /// pre-populated with the given properties (cocoa keys, per Balances.sdef).
    /// `tsx year` is not creatable, so any other class falls back to the
    /// default implementation (which raises an "unsupported" error).
    override open func newScriptingObject(of objectClass: AnyClass,
                                           forValueForKey key: String,
                                           withContentsValue contentsValue: Any?,
                                           properties: [String: Any]) -> Any? {
        guard objectClass === BalanceEntry.self else {
            return super.newScriptingObject(of: objectClass, forValueForKey: key,
                                              withContentsValue: contentsValue, properties: properties)
        }
        let entry = BalanceEntry(context: viewContext)
        entry.id = UUID()
        entry.date = Date()
        entry.balance = 0
        entry.adjustment = 0
        entry.transfers = 0
        // Apply only the known, scriptable keys explicitly: an unrecognized
        // key passed to setValue(forKey:) raises an uncaught NSException
        // (e.g. "make ... with properties {id: ...}" for the read-only id).
        for (key, value) in properties {
            switch key {
            case "date":
                if let d = value as? Date { entry.date = d }
            case "balance":
                if let n = value as? NSNumber { entry.balance = n.doubleValue }
            case "adjustment":
                if let n = value as? NSNumber { entry.adjustment = n.doubleValue }
            case "transfers":
                if let n = value as? NSNumber { entry.transfers = n.doubleValue }
            case "note":
                entry.note = value as? String
            default:
                break
            }
        }
        return entry
    }

    /// The commit point for `make new balance entry`: the object is already
    /// inserted into the context (see above), so just persist it.
    @objc func insertObject(_ entry: BalanceEntry, inBalanceEntriesAtIndex index: Int) {
        try? viewContext.save()
    }
}

extension BalanceEntry {
    /// Stable string identifier used for AppleScript `id` properties.
    @objc var scriptID: String { id?.uuidString ?? "" }

    override open var objectSpecifier: NSScriptObjectSpecifier? {
        guard let appDescription = NSScriptClassDescription(for: NSApplication.self),
              let index = NSApp.balanceEntries.firstIndex(of: self) else { return nil }
        return NSIndexSpecifier(containerClassDescription: appDescription,
                                 containerSpecifier: nil,
                                 key: "balanceEntries",
                                 index: index)
    }
}

extension TSXYear {
    @objc var scriptID: String { id?.uuidString ?? "" }

    override open var objectSpecifier: NSScriptObjectSpecifier? {
        guard let appDescription = NSScriptClassDescription(for: NSApplication.self),
              let index = NSApp.tsxYears.firstIndex(of: self) else { return nil }
        return NSIndexSpecifier(containerClassDescription: appDescription,
                                 containerSpecifier: nil,
                                 key: "tsxYears",
                                 index: index)
    }
}
