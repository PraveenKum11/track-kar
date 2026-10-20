import Charts
import SwiftUI

/// Hours per day (or week), stacked by activity or group, with a hover tooltip.
struct DailyStackedChart: View {
    let amounts: [DailyAmount]
    /// The full range to show, so empty buckets still take up space.
    let buckets: [DateInterval]
    var unit: Calendar.Component = .day
    var emptyMessage: LocalizedStringKey = "No time tracked in this period."

    @Environment(\.appTheme) private var theme
    @State private var hoveredBucket: DateInterval?

    /// Series ordered by total time, largest first, with "Other" last.
    private var series: [(name: String, colorHex: String)] {
        var totals: [String: (colorHex: String, seconds: TimeInterval)] = [:]
        for amount in amounts {
            totals[amount.series, default: (amount.colorHex, 0)].seconds += amount.seconds
        }
        let other = String(localized: "Other")
        return totals
            .sorted { lhs, rhs in
                if lhs.key == other { return false }
                if rhs.key == other { return true }
                return lhs.value.seconds > rhs.value.seconds
            }
            .map { ($0.key, $0.value.colorHex) }
    }

    var body: some View {
        if amounts.isEmpty {
            Text(emptyMessage)
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
                    x: .value("Date", amount.day, unit: unit),
                    y: .value("Hours", amount.hours),
                    width: .ratio(0.6)
                )
                .foregroundStyle(by: .value("Series", amount.series))
                .cornerRadius(2)
                .opacity(hoveredBucket == nil || hoveredBucket?.start == amount.day ? 1 : 0.4)
                .accessibilityLabel("\(amount.series), \(amount.day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))")
                .accessibilityValue(DurationFormat.short(amount.seconds))
            }
        }
        .chartForegroundStyleScale(
            domain: series.map(\.name),
            range: series.map { Color.activity($0.colorHex) }
        )
        .chartXScale(
            domain: (buckets.first?.start ?? .now)...(buckets.last?.end ?? .now),
            range: .plotDimension(endPadding: 24)
        )
        .chartLegend(series.count > 1 ? .visible : .hidden)
        .chartLegend(position: .bottom, alignment: .leading)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { _ in
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
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(.clear)
                        .contentShape(.rect)
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                guard let plotFrame = proxy.plotFrame else { return }
                                let x = location.x - geometry[plotFrame].origin.x
                                hoveredBucket = proxy.value(atX: x, as: Date.self).flatMap { date in
                                    buckets.first { $0.contains(date) }
                                }
                            case .ended:
                                hoveredBucket = nil
                            }
                        }

                    if let hoveredBucket,
                       let plotFrame = proxy.plotFrame,
                       let barX = proxy.position(forX: hoveredBucket.start.addingTimeInterval(hoveredBucket.duration / 2)) {
                        positionedTooltip(
                            for: hoveredBucket,
                            barX: geometry[plotFrame].origin.x + barX,
                            top: geometry[plotFrame].origin.y,
                            width: geometry.size.width
                        )
                    }
                }
            }
        }
    }

    /// Sits beside the hovered bar, on whichever side has more room.
    private func positionedTooltip(for bucket: DateInterval, barX: CGFloat, top: CGFloat, width: CGFloat) -> some View {
        let onLeft = barX > width / 2
        return HStack(spacing: 0) {
            if onLeft { Spacer(minLength: 0) }
            tooltip(for: bucket)
                .fixedSize()
            if !onLeft { Spacer(minLength: 0) }
        }
        .padding(.leading, onLeft ? 0 : barX + 12)
        .padding(.trailing, onLeft ? width - barX + 12 : 0)
        .padding(.top, top)
        .allowsHitTesting(false)
    }

    private func tooltip(for bucket: DateInterval) -> some View {
        let bucketAmounts = amounts.filter { $0.day == bucket.start }
        let total = bucketAmounts.reduce(0) { $0 + $1.seconds }
        let title = unit == .day
            ? bucket.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            : String(localized: "Week of \(bucket.start.formatted(.dateTime.month(.abbreviated).day()))")
        return VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
            if bucketAmounts.isEmpty {
                Text("Nothing tracked")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
            ForEach(bucketAmounts) { amount in
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
            if bucketAmounts.count > 1 {
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
        .frame(minWidth: 140)
        .background(.regularMaterial, in: .rect(cornerRadius: 8))
        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
    }
}
