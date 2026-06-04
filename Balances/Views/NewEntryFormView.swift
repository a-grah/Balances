import SwiftUI
import CoreData

/// The dashboard "NEW ENTRY" form. Adds a dated balance snapshot.
struct NewEntryFormView: View {
    @Environment(\.managedObjectContext) private var context

    @State private var dateText = Fmt.isoString(Date())
    @State private var balance = ""
    @State private var adjustment = ""
    @State private var transfers = ""
    @State private var note = ""
    @State private var errorMessage: String?

    private var balanceValue: Double? { Double(balance.trimmingCharacters(in: .whitespaces)) }
    private var dateValue: Date? { Fmt.parseDay(dateText) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Entry")
                .font(.title2).bold()

            VStack(alignment: .leading, spacing: 4) {
                field("Date", text: $dateText, prompt: "YYYY-MM-DD")
                if !dateText.trimmingCharacters(in: .whitespaces).isEmpty, dateValue == nil {
                    Text("Use YYYY-MM-DD format (e.g. 2026-06-04).")
                        .foregroundStyle(.red).font(.caption)
                }
            }

            field("Balance", text: $balance, prompt: "Required, e.g. 1242000")
            field("Adjustment", text: $adjustment, prompt: "Cash flow: + deposit / − withdrawal")
            field("Transfers", text: $transfers, prompt: "Optional")

            VStack(alignment: .leading, spacing: 4) {
                Text("Note").font(.caption).foregroundStyle(.secondary)
                TextField("Optional", text: $note, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.caption)
            }

            HStack {
                Button("Clear", role: .cancel, action: clear)
                Spacer()
                Button("Submit", action: submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(balanceValue == nil || dateValue == nil)
            }
        }
    }

    private func field(_ label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func submit() {
        guard let balanceValue else {
            errorMessage = "Balance must be a number."
            return
        }
        guard let date = dateValue else {
            errorMessage = "Date must be in YYYY-MM-DD format."
            return
        }
        let e = BalanceEntry(context: context)
        e.id = UUID()
        e.date = date
        e.balance = balanceValue
        e.adjustment = Double(adjustment.trimmingCharacters(in: .whitespaces)) ?? 0
        e.transfers = Double(transfers.trimmingCharacters(in: .whitespaces)) ?? 0
        e.note = note.isEmpty ? nil : note
        do {
            try context.save()
            clear()
        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    private func clear() {
        balance = ""; adjustment = ""; transfers = ""; note = ""
        dateText = Fmt.isoString(Date()); errorMessage = nil
    }
}
