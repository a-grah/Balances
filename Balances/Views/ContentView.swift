import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis") }

            BalancesTableView()
                .tabItem { Label("Balances", systemImage: "tablecells") }

            TSXComparisonView()
                .tabItem { Label("TSX Comparison", systemImage: "chart.bar.xaxis") }
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .frame(width: 1000, height: 700)
}
