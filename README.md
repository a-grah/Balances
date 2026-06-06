# Balances

A native macOS app (SwiftUI + Core Data) for tracking an investment portfolio over time. It logs dated balance snapshots, shows portfolio statistics and a balance-over-time chart, and benchmarks performance against the S&P/TSX Composite. Modeled on a "Portfolio Balance Performance" spreadsheet.

## Features

**Dashboard**
- New-entry form: date (`YYYY-MM-DD`), balance, cash-flow adjustment, optional transfers and note, with inline date validation.
- Portfolio stats: maximum balance, average balance over 1/3/6/12 months, total deposits and withdrawals.
- Summary: starting balance, net cash flows, current value, investment gain (excluding cash flows), and gain %.
- Balance-over-time chart (Swift Charts) with `1M / 3M / 6M / 1Y / 5Y / All` ranges that scales to the window, plus an "Adjusted" overlay showing performance with cash flows removed.

**Balances**
- Editable table of all entries with a computed **Adjusted Balance** column.
- Add, edit (sheet), and delete entries; toolbar buttons with tooltips.
- **CSV export** and **import** (tolerant of common date formats and currency-formatted numbers like `$1,234` and `(500)`), with an import confirmation.
- **Undo / redo** (⌘Z / ⇧⌘Z, also in the Edit menu) for add, edit, delete, and import.

**TSX Comparison**
- Editable yearly benchmark (index return, cash flows, actual start/end) with a chained "TSX Simulated" value.
- Summary comparing **Your Portfolio** vs **TSX Equivalent** vs **Difference**. The Your-Portfolio column is computed from your real balance entries (so it matches the Dashboard).

## Requirements

- macOS 14.0 or later (deployment target)
- Xcode 16+ / Swift 5+ to build (developed with Xcode 26)

## Build & run

Open in Xcode and run the **Balances** scheme, or from the command line:

```sh
# Debug build
xcodebuild -project Balances.xcodeproj -scheme Balances -configuration Debug \
  -destination 'platform=macOS' build

# Release build (ad-hoc signed, universal)
xcodebuild -project Balances.xcodeproj -scheme Balances -configuration Release \
  -sdk macosx CODE_SIGN_IDENTITY="-" ONLY_ACTIVE_ARCH=NO build
```

The built app is under `build/<config>/Balances.app`. To install for everyday use, copy it to `/Applications`.

## Data & storage

- Data is stored in a **Core Data / SQLite** store inside the app's sandbox container:
  `~/Library/Containers/ca.bluepill.Balances/Data/Library/Application Support/Balances/Balances.sqlite`
- On first launch the store is seeded from bundled JSON in `Balances/Resources/` (`balances_seed.json`, `tsx_seed.json`) if present.

> **Privacy note:** the seed JSON contains real portfolio data and is **git-ignored** (not tracked in this repository). A fresh clone has no seed files, so the app launches with an empty store — enter data manually or import a CSV.

## Project structure

```
Balances.xcodeproj            # hand-authored Xcode project
Balances/
  BalancesApp.swift           # @main; Core Data context + undo manager + menu commands
  Persistence.swift           # NSPersistentContainer (SQLite)
  Balances.xcdatamodeld       # BalanceEntry, TSXYear entities
  Assets.xcassets             # app icon
  Model/
    PortfolioStats.swift      # stats, adjusted-balance series, summary, TSX simulation
    DateRange.swift           # chart time-range enum
    SeedImporter.swift        # first-launch seeding from bundled JSON
    CSVPorter.swift           # CSV import/export
    CoreDataAdapters.swift    # managed object -> value-type adapters
    Formatters.swift          # currency / percent / date formatting
  Views/
    ContentView.swift         # TabView: Dashboard / Balances / TSX Comparison
    DashboardView.swift, NewEntryFormView.swift, StatsPanelView.swift, BalanceChartView.swift
    BalancesTableView.swift   # editable table + CSV + editor sheet
    TSXComparisonView.swift   # yearly benchmark + comparison summary
  Resources/                  # seed JSON (git-ignored)
```

## Notes

- **TSX simulation** intentionally mirrors the source spreadsheet's chaining (the second year re-bases to its own actual start, then later years compound), so the simulated value matches the original sheet. See `TSXModel.simulate` in `Model/PortfolioStats.swift`.
- The app is **ad-hoc signed** for personal use. Sharing it with others would require Developer ID signing + notarization to avoid Gatekeeper prompts.

## Versioning

Current version **1.2**. Tagged releases: `v1.1`, `v1.2`.
