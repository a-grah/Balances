import SwiftUI
import CoreData

/// Year-by-year TSX benchmark plus the Your Portfolio vs TSX summary.
struct TSXComparisonView: View {
    @Environment(\.managedObjectContext) private var context

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TSXYear.sortOrder, ascending: true)],
        animation: .default
    )
    private var years: FetchedResults<TSXYear>

    @State private var selection: TSXYear.ID?
    @State private var editorYear: TSXYear?
    @State private var showEditor = false

    private var simulatedByOrder: [Int: Double] {
        var map: [Int: Double] = [:]
        for row in TSXModel.simulate(Array(years).inputs) {
            map[row.input.sortOrder] = row.simulated
        }
        return map
    }

    var body: some View {
        let sims = simulatedByOrder
        VSplitView {
            VStack(spacing: 0) {
                Text("Portfolio vs S&P/TSX Composite (Total Return)")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)

                Table(years, selection: $selection) {
                    TableColumn("Year") { y in Text(y.displayName) }
                        .width(min: 70, ideal: 90)
                    TableColumn("TSX Return") { y in
                        Text(Fmt.pct(y.tsxReturn)).monospacedDigit()
                            .foregroundStyle(y.tsxReturn >= 0 ? .green : .red)
                    }
                    .width(min: 80, ideal: 100)
                    TableColumn("Net Cash Flows") { y in
                        Text(Fmt.money(y.netCashFlows)).monospacedDigit()
                    }
                    .width(min: 100, ideal: 120)
                    TableColumn("Actual Start") { y in
                        Text(Fmt.money(y.actualStart)).monospacedDigit()
                    }
                    .width(min: 100, ideal: 120)
                    TableColumn("Actual End") { y in
                        Text(Fmt.money(y.actualEnd)).monospacedDigit()
                    }
                    .width(min: 100, ideal: 120)
                    TableColumn("TSX Simulated") { y in
                        Text(Fmt.money(sims[Int(y.sortOrder)] ?? 0))
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                    .width(min: 100, ideal: 120)
                }
                .contextMenu(forSelectionType: TSXYear.ID.self) { _ in
                    Button("Edit") { editSelected() }
                    Button("Delete", role: .destructive) { deleteSelected() }
                } primaryAction: { ids in
                    if let id = ids.first { edit(id) }
                }
            }
            .frame(minHeight: 220)

            ScrollView {
                summaryView.padding()
            }
            .frame(minHeight: 180)
        }
        .toolbar {
            ToolbarItemGroup {
                Button { addYear() } label: { Label("Add Year", systemImage: "plus") }
                Button { editSelected() } label: { Label("Edit", systemImage: "pencil") }
                    .disabled(selection == nil)
                Button(role: .destructive) { deleteSelected() } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(selection == nil)
            }
        }
        .sheet(isPresented: $showEditor) {
            if let editorYear {
                TSXYearEditorView(year: editorYear)
                    .environment(\.managedObjectContext, context)
            }
        }
    }

    @ViewBuilder
    private var summaryView: some View {
        if let cmp = TSXModel.comparison(Array(years).inputs) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Summary").font(.title3).bold()
                Grid(alignment: .trailing, horizontalSpacing: 24, verticalSpacing: 8) {
                    GridRow {
                        Text("").gridColumnAlignment(.leading)
                        Text("Your Portfolio").bold()
                        Text("TSX Equivalent").bold()
                        Text("Difference").bold()
                    }
                    Divider().gridCellColumns(4)
                    row("Starting Balance", cmp.startingBalance)
                    row("Net Cash Flows", cmp.netCashFlows)
                    row("Current Value", cmp.currentValue)
                    row("Investment Gain (excl. cash flows)", cmp.investmentGain)
                    pctRow("Gain as % of Start + Cash Flows", cmp.gainPercent)
                }
            }
        } else {
            Text("Add yearly data to see the comparison.")
                .foregroundStyle(.secondary)
        }
    }

    private func row(_ label: String, _ vals: (portfolio: Double, tsx: Double)) -> some View {
        GridRow {
            Text(label).gridColumnAlignment(.leading).foregroundStyle(.secondary)
            Text(Fmt.money(vals.portfolio)).monospacedDigit()
            Text(Fmt.money(vals.tsx)).monospacedDigit()
            Text(Fmt.money(vals.portfolio - vals.tsx)).monospacedDigit()
                .foregroundStyle((vals.portfolio - vals.tsx) >= 0 ? .green : .red)
        }
    }

    private func pctRow(_ label: String, _ vals: (portfolio: Double, tsx: Double)) -> some View {
        GridRow {
            Text(label).gridColumnAlignment(.leading).foregroundStyle(.secondary)
            Text(Fmt.pct(vals.portfolio)).monospacedDigit()
            Text(Fmt.pct(vals.tsx)).monospacedDigit()
            Text(Fmt.pct(vals.portfolio - vals.tsx)).monospacedDigit()
                .foregroundStyle((vals.portfolio - vals.tsx) >= 0 ? .green : .red)
        }
    }

    private func addYear() {
        let y = TSXYear(context: context)
        y.id = UUID()
        let maxOrder = years.map { Int($0.sortOrder) }.max() ?? -1
        y.sortOrder = Int16(maxOrder + 1)
        y.year = Int32((years.compactMap { $0.year == 0 ? nil : Int($0.year) }.max() ?? 2014) + 1)
        editorYear = y
        showEditor = true
    }

    private func editSelected() {
        if let id = selection { edit(id) }
    }

    private func edit(_ id: TSXYear.ID) {
        editorYear = years.first { $0.id == id }
        showEditor = editorYear != nil
    }

    private func deleteSelected() {
        guard let id = selection, let y = years.first(where: { $0.id == id }) else { return }
        context.delete(y)
        selection = nil
        try? context.save()
    }
}

struct TSXYearEditorView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var year: TSXYear

    @State private var label = ""
    @State private var yearText = ""
    @State private var tsxReturn = ""
    @State private var netCashFlows = ""
    @State private var actualStart = ""
    @State private var actualEnd = ""
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(year.isInserted ? "Add Year" : "Edit Year").font(.title2).bold()

            LabeledContent("Year") {
                TextField("e.g. 2025", text: $yearText).textFieldStyle(.roundedBorder)
            }
            LabeledContent("Label (optional)") {
                TextField("e.g. 2026 YTD", text: $label).textFieldStyle(.roundedBorder)
            }
            LabeledContent("TSX Return (decimal)") {
                TextField("e.g. 0.215 for 21.5%", text: $tsxReturn).textFieldStyle(.roundedBorder)
            }
            LabeledContent("Net Cash Flows") {
                TextField("0", text: $netCashFlows).textFieldStyle(.roundedBorder)
            }
            LabeledContent("Actual Start") {
                TextField("0", text: $actualStart).textFieldStyle(.roundedBorder)
            }
            LabeledContent("Actual End") {
                TextField("0", text: $actualEnd).textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel", role: .cancel) { cancel() }
                Spacer()
                Button("Save") { save() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 380)
        .onAppear(perform: load)
    }

    private func load() {
        guard !loaded else { return }
        label = year.label ?? ""
        yearText = year.year == 0 ? "" : String(year.year)
        tsxReturn = year.tsxReturn == 0 ? "" : String(year.tsxReturn)
        netCashFlows = year.netCashFlows == 0 ? "" : String(year.netCashFlows)
        actualStart = year.actualStart == 0 ? "" : String(year.actualStart)
        actualEnd = year.actualEnd == 0 ? "" : String(year.actualEnd)
        loaded = true
    }

    private func save() {
        if year.id == nil { year.id = UUID() }
        year.label = label.isEmpty ? nil : label
        year.year = Int32(yearText.trimmingCharacters(in: .whitespaces)) ?? 0
        year.tsxReturn = Double(tsxReturn.trimmingCharacters(in: .whitespaces)) ?? 0
        year.netCashFlows = Double(netCashFlows.trimmingCharacters(in: .whitespaces)) ?? 0
        year.actualStart = Double(actualStart.trimmingCharacters(in: .whitespaces)) ?? 0
        year.actualEnd = Double(actualEnd.trimmingCharacters(in: .whitespaces)) ?? 0
        try? context.save()
        dismiss()
    }

    private func cancel() {
        if year.isInserted { context.delete(year) }
        context.rollback()
        dismiss()
    }
}
