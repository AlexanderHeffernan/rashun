import AppKit
import Foundation

@MainActor
final class UsageHistoryViewModel: ObservableObject {
    @Published var timeRange: ChartTimeRange = .week {
        didSet { reloadChart() }
    }
    @Published private(set) var series: [ChartSeries] = []
    @Published private(set) var summaryLines: [String] = []
    @Published private(set) var visibleStartDate: Date?
    @Published private(set) var visibleEndDate: Date?
    @Published private(set) var hasEnabledSources = false
    @Published private(set) var hiddenSeriesLabels: Set<String> = []

    private var currentSources: [AISource] = []

    private static let palette: [NSColor] = [
        .systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemRed
    ]

    var visibleSeries: [ChartSeries] {
        series.filter { !hiddenSeriesLabels.contains($0.label) }
    }

    func isSeriesVisible(_ label: String) -> Bool {
        !hiddenSeriesLabels.contains(label)
    }

    func toggleSeriesVisibility(_ label: String) {
        if hiddenSeriesLabels.contains(label) {
            hiddenSeriesLabels.remove(label)
        } else {
            hiddenSeriesLabels.insert(label)
        }
    }

    func configure(withSources sources: [AISource]) {
        currentSources = sources
        reloadChart()
    }

    func reloadChart() {
        let enabledSources = currentSources.filter { SettingsStore.shared.isEnabled(sourceName: $0.name) }
        hasEnabledSources = !enabledSources.isEmpty

        var chartSeries: [ChartSeries] = []
        var summaries: [String] = []
        let now = Date()
        let bounds = timeRange.rangeBounds(now: now)
        let showForecast = timeRange != .all
        var seriesIndex = 0

        for source in enabledSources {
            let enabledMetrics = source.usageMetrics
                .filter { SettingsStore.shared.isMetricEnabled(sourceName: source.name, metricId: $0.id) }

            if source.usageMetrics.count <= 1 {
                let color = Self.palette[seriesIndex % Self.palette.count]
                seriesIndex += 1
                let history = NotificationHistoryStore.shared.history(for: source.name)
                let points = filterPoints(history, bounds: bounds)
                let forecastPoints = filteredForecastPoints(source: source, history: history, points: points, bounds: bounds, showForecast: showForecast)
                if showForecast, let current = history.last?.usage, let forecast = source.forecast(current: current, history: history) {
                    summaries.append(forecast.summary)
                }
                chartSeries.append(ChartSeries(label: source.name, color: color, points: points, forecast: forecastPoints))
                continue
            }

            for metric in enabledMetrics {
                let color = Self.palette[seriesIndex % Self.palette.count]
                seriesIndex += 1
                var history = NotificationHistoryStore.shared.history(for: metricHistorySeriesName(source: source, metric: metric))
                if history.isEmpty, metric.id == source.usageMetrics.first?.id {
                    history = NotificationHistoryStore.shared.history(for: source.name)
                }

                let points = filterPoints(history, bounds: bounds)
                let forecastPoints = filteredForecastPoints(source: source, history: history, points: points, bounds: bounds, showForecast: showForecast)

                if showForecast, let current = history.last?.usage, let forecast = source.forecast(current: current, history: history) {
                    summaries.append(forecastSummary(label: "\(source.name) - \(metric.title)", original: forecast.summary))
                }

                chartSeries.append(
                    ChartSeries(
                        label: "\(source.name) - \(metric.title)",
                        color: color,
                        points: points,
                        forecast: forecastPoints
                    )
                )
            }
        }

        series = chartSeries
        let availableLabels = Set(chartSeries.map(\.label))
        hiddenSeriesLabels = hiddenSeriesLabels.intersection(availableLabels)
        summaryLines = summaries
        visibleStartDate = bounds.start
        visibleEndDate = bounds.end
    }

    private func metricHistorySeriesName(source: AISource, metric: AISourceMetric) -> String {
        "\(source.name) - \(metric.title)"
    }

    private func filterPoints(_ history: [UsageSnapshot], bounds: (start: Date?, end: Date?)) -> [ChartPoint] {
        var points = history
            .map { ChartPoint(date: $0.timestamp, value: $0.usage.percentRemaining) }
            .sorted(by: { $0.date < $1.date })

        if let start = bounds.start {
            points = points.filter { $0.date >= start }
        }
        if let end = bounds.end {
            points = points.filter { $0.date <= end }
        }

        return points
    }

    private func filteredForecastPoints(
        source: AISource,
        history: [UsageSnapshot],
        points: [ChartPoint],
        bounds: (start: Date?, end: Date?),
        showForecast: Bool
    ) -> [ChartPoint] {
        guard showForecast,
              let current = history.last?.usage,
              let forecast = source.forecast(current: current, history: history) else {
            return []
        }

        var sourceForecastPoints = forecast.points
            .map { ChartPoint(date: $0.date, value: $0.value) }
            .sorted(by: { $0.date < $1.date })

        if let start = bounds.start {
            sourceForecastPoints = sourceForecastPoints.filter { $0.date >= start }
        }
        if let end = bounds.end {
            sourceForecastPoints = sourceForecastPoints.filter { $0.date <= end }
        }
        if let lastActual = points.last,
           let firstForecast = sourceForecastPoints.first,
           firstForecast.date > lastActual.date {
            sourceForecastPoints.insert(lastActual, at: 0)
        }

        return sourceForecastPoints
    }

    private func forecastSummary(label: String, original: String) -> String {
        if let separatorRange = original.range(of: ":") {
            return "\(label)\(original[separatorRange.lowerBound...])"
        }
        return "\(label): \(original)"
    }
}
