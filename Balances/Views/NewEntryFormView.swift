import SwiftUI
import CoreData
import AppKit
import Combine

/// The dashboard "NEW ENTRY" form. Adds a dated balance snapshot.
struct NewEntryFormView: View {
    private enum Field: Hashable {
        case date, balance, adjustment, transfers, note
    }

    @Environment(\.managedObjectContext) private var context
    @FocusState private var focusedField: Field?

    @State private var dateText = Fmt.isoString(Date())
    /// The last date this form filled in on its own. While `dateText` still matches it,
    /// the field is untouched and free to roll forward as the calendar day changes.
    @State private var autoDateText = Fmt.isoString(Date())
    @State private var balance = ""
    @State private var adjustment = ""
    @State private var transfers = ""
    @State private var note = ""
    @State private var errorMessage: String?
    @State private var showDatePicker = false

    private var balanceValue: Double? { Fmt.finiteNumber(balance) }
    private var dateValue: Date? { Fmt.parseDay(dateText) }

    private var datePickerBinding: Binding<Date> {
        Binding(
            get: { dateValue ?? Date() },
            set: { dateText = Fmt.isoString($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Entry")
                .font(.title2).bold()

            VStack(alignment: .leading, spacing: 4) {
                Text("Date").font(.caption).foregroundStyle(.secondary)
                HStack {
                    TextField("YYYY-MM-DD", text: $dateText)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .date)
                        .onSubmit { focusedField = .balance }
                    Button {
                        showDatePicker = true
                    } label: {
                        Image(systemName: "calendar")
                    }
                    .popover(isPresented: $showDatePicker) {
                        DatePicker("", selection: datePickerBinding, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                            .padding()
                            .onChange(of: dateText) { showDatePicker = false }
                    }
                }
                if !dateText.trimmingCharacters(in: .whitespaces).isEmpty, dateValue == nil {
                    Text("Use YYYY-MM-DD format (e.g. 2026-06-04).")
                        .foregroundStyle(.red).font(.caption)
                }
            }

            field("Balance", text: $balance, prompt: "Required, e.g. 1242000", focus: .balance, next: .adjustment)
            field("Adjustment", text: $adjustment, prompt: "Cash flow: + deposit / − withdrawal", focus: .adjustment, next: .transfers)
            field("Transfers", text: $transfers, prompt: "Optional", focus: .transfers, next: .note)

            VStack(alignment: .leading, spacing: 4) {
                Text("Note").font(.caption).foregroundStyle(.secondary)
                TextField("Optional", text: $note, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                    .focused($focusedField, equals: .note)
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.caption)
            }

            HStack {
                Button("Clear", role: .cancel, action: clear)
                Spacer()
                Button("Submit", action: submit)
                    .disabled(balanceValue == nil || dateValue == nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
            refreshAutoDate()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshAutoDate()
        }
    }

    /// Advances an untouched date field to today (midnight rollover, wake from sleep,
    /// or returning to the app after leaving it open overnight).
    private func refreshAutoDate() {
        let today = Fmt.isoString(Date())
        guard today != autoDateText else { return }
        if dateText == autoDateText { dateText = today }
        autoDateText = today
    }

    private func field(_ label: String, text: Binding<String>, prompt: String, focus: Field, next: Field) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: focus)
                .onSubmit { focusedField = next }
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
        e.adjustment = Fmt.finiteNumber(adjustment) ?? 0
        e.transfers = Fmt.finiteNumber(transfers) ?? 0
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
        dateText = Fmt.isoString(Date()); autoDateText = dateText; errorMessage = nil
    }
}
