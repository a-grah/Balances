# Balances

[![Build](https://github.com/a-grah/Balances/actions/workflows/build.yml/badge.svg)](https://github.com/a-grah/Balances/actions/workflows/build.yml)

A native macOS app (SwiftUI + Core Data) for tracking an investment portfolio over time. It logs dated balance snapshots, shows portfolio statistics and a balance-over-time chart, and benchmarks performance against the S&P/TSX Composite. Modeled on a "Portfolio Balance Performance" spreadsheet.

## Overview

Balances is a personal app for tracking your investment portfolio over time and seeing how well it's actually doing.

**Keep a running record of your money.** You log your account balance whenever you like — along with any deposits, withdrawals, or transfers — and the app builds a history out of those entries. A chart shows how your balance has moved over time, with quick filters for the last month, three months, six months, year, or the whole history.

**See the numbers that matter.** At a glance you get your current value, your highest balance ever, rolling averages over different periods, total deposits and withdrawals, and how much of your growth came from actual investment gains versus money you simply added. In other words, it separates "my portfolio grew because it performed well" from "my portfolio grew because I put more in."

**Compare yourself to the market.** A dedicated section pits your portfolio against the S&P/TSX Composite index, year by year. It simulates what your money *would* have done if you'd just invested in the index instead — same starting point, same cash flows — so you can see whether your investing is genuinely beating the market or trailing it. The summary spells out the difference in plain dollars and percentages.

In short, Balances answers the questions every investor really cares about: *How am I doing? Is my money actually growing? And would I have been better off just buying the index?*

### Why not just a spreadsheet?

A spreadsheet could do most of this — the difference is friction and focus, not capability. Balances is already built for this one job, so there are no columns to design or formulas to maintain. The fiddly math — separating real gains from deposits, and simulating the index against your exact cash flows — is done for you and stays consistent, instead of being easy to get subtly wrong in a sheet. Entering data is a quick, safe form rather than navigating a growing grid where one bad paste overwrites history. And it stays focused on the few things that matter rather than sprawling over time. A spreadsheet still wins on raw flexibility; Balances trades that for being effortless at the specific thing it does.

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

> **App Intents need a properly signed build.** The ad-hoc (`CODE_SIGN_IDENTITY="-"`) builds above run fine, but the App Intents daemon (`linkd`) rejects an ad-hoc bundle — it can't validate the bundle identity (`requiresValidatedBundle`), so Shortcuts/Siri/Spotlight fail with *"Shortcuts couldn't communicate with the app"* even while the app is running. For App-Intents testing, install a Developer ID-signed copy instead — notarization is **not** required for `linkd` validation:
>
> ```sh
> SKIP_NOTARIZE=1 scripts/release.sh            # → signed dist/Balances.app
> ditto dist/Balances.app /Applications/Balances.app
> ```
>
> The real notarized release DMG is already Developer ID-signed, so shipped builds are unaffected.

## Data & storage

- Data is stored in a **Core Data / SQLite** store inside the app's sandbox container:
  `~/Library/Containers/ca.bluepill.Balances/Data/Library/Application Support/Balances/Balances.sqlite`
- On first launch the store is seeded from bundled JSON in `Balances/Resources/` (`balances_seed.json`, `tsx_seed.json`) if present.

> The bundled seed JSON is a small **synthetic sample** so a fresh build has something to show. To start empty instead, replace each file with `[]` before building, or delete the sample rows in the app.

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
  Resources/                  # synthetic sample seed JSON
```

## Notes

- **TSX simulation** intentionally mirrors the source spreadsheet's chaining (the second year re-bases to its own actual start, then later years compound), so the simulated value matches the original sheet. See `TSXModel.simulate` in `Model/PortfolioStats.swift`.
- The plain `xcodebuild` commands above produce an **ad-hoc signed** build for personal use. `scripts/release.sh` produces the Developer ID-signed, notarized DMG; it needs your own signing identity, team ID, and notarytool profile.

## License

Balances is released under the [MIT License](LICENSE).

