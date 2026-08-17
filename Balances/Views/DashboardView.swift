import SwiftUI
import CoreData

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var context

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \BalanceEntry.date, ascending: true)],
        animation: .default
    )
    private var entries: FetchedResults<BalanceEntry>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TSXYear.sortOrder, ascending: true)],
        animation: .default
    )
    private var tsxYears: FetchedResults<TSXYear>

    var body: some View {
        let inputs = Array(entries).statsInputs
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    NewEntryFormView()
                    Divider()
                    StatsPanelView(inputs: inputs)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 320, idealWidth: 360, maxWidth: 460)

            BalanceChartView(
                points: PortfolioStats.series(from: inputs),
                benchmark: TSXModel.benchmarkSeries(years: Array(tsxYears).inputs, entries: inputs)
            )
            .frame(minWidth: 420)
            .padding()
        }
    }
}

#Preview {
    DashboardView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .frame(width: 1000, height: 700)
}
