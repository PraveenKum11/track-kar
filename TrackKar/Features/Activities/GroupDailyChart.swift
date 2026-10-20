import Charts
import SwiftUI

/// Hours per day, stacked by activity, with a hover tooltip.
struct GroupDailyChart: View {
    let amounts: [DailyAmount]
    /// The full range to show, so empty days still take up space.
    let days: [DateInterval]

    @Environment(\.appTheme) private var theme
    @State private var hoveredDay: Date?

    /// Series in first-appearance order, which `Stats.dailyAmounts` ranks by total.
    private var series: [(name: String, colorHex: String)] {
        var seen = Set<String>()
        return amounts.compactMap { amount in
            seen.insert(amount.series).inserted ? (amount.series, amount.colorHex) : nil
        }
    }

    var body: some View {
        if amounts.isEmpty {
            Text("No time tracked in the last 30 days.")
                .foregroundStyle(theme.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            chart
        }
    }

    private var chart: some View {
        let series = series
        return Chart {
            ForEach(amounts) { amount in
                BarMark(
                    x: .value("Day", amount.day, unit: .day),
                    y: .value("Hours", amount.hours),
                    width: .ratio(0.6)
                )
                .foregroundStyle(by: .value("Activity", amount.series))
                .cornerRadius(2)
                .opacity(hoveredDay == nil || hoveredDay == amount.day ? 1 : 0.4)
            }
        }
        .chartForegroundStyleScale(
            domain: series.map(\.name),
            range: series.map { Color.activity($0.colorHex) }
        )
        .chartXScale(domain: (days.first?.start ?? .now)...(days.last?.end ?? .now))
        .chartLegend(series.count > 1 ? .visible : .hidden)
        .chartLegend(position: .bottom, alignment: .leading)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                    .foregroundStyle(theme.separator.opacity(0.5))
                AxisValueLabel {
                    if let hours = value.as(Double.self) {
                        Text("\(hours.formatted(.number.precision(.fractionLength(0...1))))h")
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(.rect)
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            guard let plotFrame = proxy.plotFrame else { return }
                            let x = location.x - geometry[plotFrame].origin.x
                            hoveredDay = proxy.value(atX: x, as: Date.self).map { Calendar.current.startOfDay(for: $0) }
                        case .ended:
                            hoveredDay = nil
                        }
                    }
            }
        }
        .overlay(alignment: .topTrailing) {
            if let hoveredDay {
                tooltip(for: hoveredDay)
            }
        }
    }

    private func tooltip(for day: Date) -> some View {
        let dayAmounts = amounts.filter { $0.day == day }
        let total = dayAmounts.reduce(0) { $0 + $1.seconds }
        return VStack(alignment: .leading, spacing: 4) {
            Text(day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                .font(.caption.weight(.semibold))
            ForEach(dayAmounts) { amount in
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.activity(amount.colorHex))
                        .frame(width: 6, height: 6)
                    Text(amount.series)
                    Spacer(minLength: 12)
                    Text(DurationFormat.short(amount.seconds))
                        .monospacedDigit()
                }
                .font(.caption)
            }
            if dayAmounts.count != 1 {
                Divider()
                HStack {
                    Text("Total")
                    Spacer(minLength: 12)
                    Text(DurationFormat.short(total))
                        .monospacedDigit()
                }
                .font(.caption.weight(.medium))
            }
        }
        .padding(8)
        .frame(minWidth: 160)
        .background(.regularMaterial, in: .rect(cornerRadius: 8))
        .allowsHitTesting(false)
    }
}
