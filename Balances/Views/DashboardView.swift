import SwiftUI
import CoreData

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var context

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \BalanceEntry.date, ascending: true)],
        animation: .default
    )
    private var entries: FetchedResults<BalanceEntry>

    var body: some View {
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    NewEntryFormView()
                    Divider()
                    StatsPanelView(inputs: Array(entries).statsInputs)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 320, idealWidth: 360, maxWidth: 460)

            BalanceChartView(points: PortfolioStats.series(from: Array(entries).statsInputs))
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
