import SwiftUI
import Charts

/// Balance-over-time line chart with a time-range selector.
/// Fills its container so it scales with the window.
struct BalanceChartView: View {
    let points: [BalancePoint]
    /// Simulated TSX benchmark, one point per year (see TSXModel.benchmarkSeries).
    var benchmark: [BenchmarkPoint] = []

    @State private var range: DateRange = .all
    @State private var showAdjusted = false
    @State private var showBenchmark = false

    private var filteredBenchmark: [BenchmarkPoint] {
        guard let start = range.startDate() else { return benchmark }
        return benchmark.filter { $0.date >= start }
    }

    private var filtered: [BalancePoint] {
        let base: [BalancePoint]
        if let start = range.startDate() {
            base = points.filter { $0.date >= start }
        } else {
            base = points
        }
        return collapseByDay(base)
    }

    /// The data has multiple snapshots on some dates; collapse to one point
    /// per calendar day (keeping the latest) so the area/line fill cannot
    /// self-intersect on duplicate x-values.
    private func collapseByDay(_ pts: [BalancePoint]) -> [BalancePoint] {
        let cal = Calendar.current
        var byDay: [Date: BalancePoint] = [:]
        for p in pts.sorted(by: { $0.date < $1.date }) {
            byDay[cal.startOfDay(for: p.date)] = p
        }
        return byDay.values.sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Balance Over Time").font(.title2).bold()
                Spacer()
                Toggle("Adjusted", isOn: $showAdjusted)
                    .toggleStyle(.switch)
                    .help("Show balance with cash flows removed (investment-only)")
                Toggle("TSX", isOn: $showBenchmark)
                    .toggleStyle(.switch)
                    .disabled(benchmark.isEmpty)
                    .help(benchmark.isEmpty
                          ? "Add yearly data on the TSX Comparison tab to plot the benchmark"
                          : "Overlay the simulated TSX value, one point per year")
            }

            Picker("Range", selection: $range) {
                ForEach(DateRange.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if filtered.isEmpty {
                ContentUnavailableView("No data in range", systemImage: "chart.line.downtrend.xyaxis")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                chart
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var chart: some View {
        Chart {
            ForEach(filtered) { p in
                AreaMark(
                    x: .value("Date", p.date),
                    y: .value("Balance", p.balance)
                )
                .foregroundStyle(
                    .linearGradient(colors: [.blue.opacity(0.22), .blue.opacity(0.02)],
                                    startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.linear)
            }

            ForEach(filtered) { p in
                LineMark(
                    x: .value("Date", p.date),
                    y: .value("Balance", p.balance),
                    series: .value("Series", "Balance")
                )
                .foregroundStyle(.blue)
                .interpolationMethod(.linear)
            }

            if showAdjusted {
                ForEach(filtered) { p in
                    LineMark(
                        x: .value("Date", p.date),
                        y: .value("Adjusted", p.adjusted),
                        series: .value("Series", "Adjusted")
                    )
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .interpolationMethod(.linear)
                }
            }

            if showBenchmark {
                ForEach(filteredBenchmark) { p in
                    LineMark(
                        x: .value("Date", p.date),
                        y: .value("TSX", p.value),
                        series: .value("Series", "TSX")
                    )
                    .foregroundStyle(.purple)
                    .interpolationMethod(.linear)

                    // The benchmark is annual, so mark the points it is
                    // actually defined at rather than implying a daily curve.
                    PointMark(
                        x: .value("Date", p.date),
                        y: .value("TSX", p.value)
                    )
                    .foregroundStyle(.purple)
                    .symbolSize(24)
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(Fmt.money(v))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) {
                AxisGridLine()
                AxisValueLabel(format: .dateTime.year().month(.abbreviated))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
