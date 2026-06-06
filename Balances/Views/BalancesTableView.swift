import SwiftUI
import CoreData

/// Editable balances table with add / edit / delete and CSV export/import.
struct BalancesTableView: View {
    @Environment(\.managedObjectContext) private var context

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \BalanceEntry.date, ascending: false)],
        animation: .default
    )
    private var entries: FetchedResults<BalanceEntry>

    @State private var selection = Set<BalanceEntry.ID>()
    @State private var editorEntry: BalanceEntry?
    @State private var showEditor = false

    private var adjustedByID: [NSManagedObjectID: Double] {
        var map: [NSManagedObjectID: Double] = [:]
        let sorted = entries.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        var running = 0.0
        for e in sorted {
            running += e.adjustment
            map[e.objectID] = e.balance - running
        }
        return map
    }

    var body: some View {
        let adjusted = adjustedByID
        VStack(spacing: 0) {
            Table(entries, selection: $selection) {
                TableColumn("Date") { e in
                    Text(e.date.map(Fmt.day) ?? "—")
                }
                .width(min: 110, ideal: 130)

                TableColumn("Balance") { e in
                    Text(Fmt.money(e.balance)).monospacedDigit()
                }
                .width(min: 90, ideal: 110)

                TableColumn("Adjustment") { e in
                    Text(e.adjustment == 0 ? "—" : Fmt.money(e.adjustment))
                        .monospacedDigit()
                        .foregroundStyle(e.adjustment > 0 ? .green : (e.adjustment < 0 ? .red : .secondary))
                }
                .width(min: 90, ideal: 110)

                TableColumn("Transfers") { e in
                    Text(e.transfers == 0 ? "—" : Fmt.moneyCents(e.transfers))
                        .monospacedDigit().foregroundStyle(.secondary)
                }
                .width(min: 70, ideal: 90)

                TableColumn("Adj. Balance") { e in
                    Text(Fmt.money(adjusted[e.objectID] ?? e.balance))
                        .monospacedDigit().foregroundStyle(.secondary)
                }
                .width(min: 90, ideal: 110)

                TableColumn("Note") { e in
                    Text(e.note ?? "")
                }
                .width(min: 120, ideal: 220)
            }
            .contextMenu(forSelectionType: BalanceEntry.ID.self) { _ in
                Button("Edit") { editSelected() }
                Button("Delete", role: .destructive) { deleteSelected() }
            } primaryAction: { ids in
                if let id = ids.first { editEntry(with: id) }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button { addEntry() } label: { Label("Add", systemImage: "plus") }
                    .help("Add a new balance entry")
                Button { editSelected() } label: { Label("Edit", systemImage: "pencil") }
                    .disabled(selection.count != 1)
                    .help("Edit the selected entry")
                Button(role: .destructive) { deleteSelected() } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(selection.isEmpty)
                .help("Delete the selected entries")
                Divider()
                Button { CSVPorter.export(Array(entries)) } label: {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
                .help("Export all entries to a CSV file")
                Button { importCSV() } label: {
                    Label("Import CSV", systemImage: "square.and.arrow.down")
                }
                .help("Import entries from a CSV file")
            }
        }
        .sheet(isPresented: $showEditor) {
            if let editorEntry {
                EntryEditorView(entry: editorEntry)
                    .environment(\.managedObjectContext, context)
            }
        }
    }

    private func addEntry() {
        let e = BalanceEntry(context: context)
        e.id = UUID()
        e.date = Date()
        e.balance = 0
        editorEntry = e
        showEditor = true
    }

    private func editSelected() {
        guard let id = selection.first else { return }
        editEntry(with: id)
    }

    private func editEntry(with id: BalanceEntry.ID) {
        editorEntry = entries.first { $0.id == id }
        showEditor = editorEntry != nil
    }

    private func deleteSelected() {
        for id in selection {
            if let e = entries.first(where: { $0.id == id }) {
                context.delete(e)
            }
        }
        selection.removeAll()
        try? context.save()
    }

    private func importCSV() {
        if let n = CSVPorter.importCSV(into: context) {
            NSLog("Imported \(n) rows")
        }
    }
}

/// Add/edit sheet for a single balance entry.
struct EntryEditorView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var entry: BalanceEntry

    @State private var dateText = ""
    @State private var balance = ""
    @State private var adjustment = ""
    @State private var transfers = ""
    @State private var note = ""
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(entry.isInserted ? "Add Entry" : "Edit Entry").font(.title2).bold()

            LabeledContent("Date") {
                TextField("YYYY-MM-DD", text: $dateText).textFieldStyle(.roundedBorder)
            }
            if !dateText.trimmingCharacters(in: .whitespaces).isEmpty, Fmt.parseDay(dateText) == nil {
                Text("Use YYYY-MM-DD format (e.g. 2026-06-04).")
                    .foregroundStyle(.red).font(.caption)
            }

            LabeledContent("Balance") {
                TextField("0", text: $balance).textFieldStyle(.roundedBorder)
            }
            LabeledContent("Adjustment") {
                TextField("0", text: $adjustment).textFieldStyle(.roundedBorder)
            }
            LabeledContent("Transfers") {
                TextField("0", text: $transfers).textFieldStyle(.roundedBorder)
            }
            LabeledContent("Note") {
                TextField("", text: $note, axis: .vertical).textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel", role: .cancel) { cancel() }
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(Double(balance.trimmingCharacters(in: .whitespaces)) == nil
                              || Fmt.parseDay(dateText) == nil)
            }
        }
        .padding()
        .frame(width: 360)
        .onAppear(perform: load)
    }

    private func load() {
        guard !loaded else { return }
        dateText = Fmt.isoString(entry.date ?? Date())
        balance = entry.isInserted && entry.balance == 0 ? "" : String(entry.balance)
        adjustment = entry.adjustment == 0 ? "" : String(entry.adjustment)
        transfers = entry.transfers == 0 ? "" : String(entry.transfers)
        note = entry.note ?? ""
        loaded = true
    }

    private func save() {
        guard let b = Double(balance.trimmingCharacters(in: .whitespaces)),
              let date = Fmt.parseDay(dateText) else { return }
        if entry.id == nil { entry.id = UUID() }
        entry.date = date
        entry.balance = b
        entry.adjustment = Double(adjustment.trimmingCharacters(in: .whitespaces)) ?? 0
        entry.transfers = Double(transfers.trimmingCharacters(in: .whitespaces)) ?? 0
        entry.note = note.isEmpty ? nil : note
        try? context.save()
        dismiss()
    }

    private func cancel() {
        if entry.isInserted {
            context.delete(entry)
        }
        context.rollback()
        dismiss()
    }
}
