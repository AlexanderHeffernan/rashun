import Cocoa

struct ChartPoint {
    let date: Date
    let value: Double
}

struct ChartSeries {
    let label: String
    let color: NSColor
    let points: [ChartPoint]
    let forecast: [ChartPoint]
}

@MainActor
class UsageChartView: NSView {

    var series: [ChartSeries] = [] {
        didSet { needsDisplay = true }
    }
    var visibleStartDate: Date? {
        didSet { needsDisplay = true }
    }
    var visibleEndDate: Date? {
        didSet { needsDisplay = true }
    }

    private let paddingTop: CGFloat = 30
    private let paddingBottom: CGFloat = 35
    private let paddingLeft: CGFloat = 55
    private let paddingRight: CGFloat = 20

    private var chartRect: NSRect {
        NSRect(
            x: bounds.minX + paddingLeft,
            y: bounds.minY + paddingBottom,
            width: bounds.width - paddingLeft - paddingRight,
            height: bounds.height - paddingTop - paddingBottom
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let chart = chartRect
        guard chart.width > 0, chart.height > 0 else { return }

        guard let (startDate, endDate) = effectiveDateRange(), endDate > startDate else {
            drawCenteredText("Not enough data yet.", in: bounds)
            return
        }

        drawGrid(in: chart, start: startDate, end: endDate)
        drawYAxisLabels(in: chart)
        drawXAxisLabels(in: chart, start: startDate, end: endDate)

        NSGraphicsContext.current?.saveGraphicsState()
        NSBezierPath(rect: chart).addClip()

        for s in series {
            drawArea(s.points, color: s.color, in: chart, start: startDate, end: endDate)
            drawLine(s.points, color: s.color, in: chart, start: startDate, end: endDate)
            drawLine(s.forecast, color: s.color.withAlphaComponent(0.65), in: chart, start: startDate, end: endDate, dashed: true)
        }

        drawNowMarker(in: chart, start: startDate, end: endDate)

        NSGraphicsContext.current?.restoreGraphicsState()

        drawLegend(in: chart)
    }

    private func effectiveDateRange() -> (Date, Date)? {
        let actualPoints = series.flatMap(\.points)
        let forecastPoints = series.flatMap(\.forecast)
        let allPoints = actualPoints + forecastPoints
        guard let earliest = allPoints.min(by: { $0.date < $1.date })?.date,
              let latest = allPoints.max(by: { $0.date < $1.date })?.date else {
            return nil
        }

        let start = visibleStartDate ?? earliest
        let end = visibleEndDate ?? max(latest, Date())
        guard end > start else { return nil }

        if visibleStartDate != nil, visibleEndDate != nil {
            return (start, end)
        }

        let padding = max(end.timeIntervalSince(start) * 0.02, 60)
        return (start.addingTimeInterval(-padding), end.addingTimeInterval(padding))
    }

    private func xFor(_ date: Date, in rect: NSRect, start: Date, end: Date) -> CGFloat {
        let fraction = date.timeIntervalSince(start) / end.timeIntervalSince(start)
        return rect.minX + rect.width * CGFloat(fraction)
    }

    private func yFor(_ value: Double, in rect: NSRect) -> CGFloat {
        rect.minY + rect.height * CGFloat(min(max(value, 0), 100) / 100.0)
    }

    private func drawGrid(in rect: NSRect, start: Date, end: Date) {
        NSColor.separatorColor.withAlphaComponent(0.25).setStroke()

        let path = NSBezierPath()
        path.lineWidth = 0.5

        for pct in stride(from: 0.0, through: 100.0, by: 25.0) {
            let y = yFor(pct, in: rect)
            path.move(to: NSPoint(x: rect.minX, y: y))
            path.line(to: NSPoint(x: rect.maxX, y: y))
        }

        let totalSeconds = end.timeIntervalSince(start)
        let gridLines = 5
        for i in 0...gridLines {
            let date = start.addingTimeInterval(totalSeconds * Double(i) / Double(gridLines))
            let x = xFor(date, in: rect, start: start, end: end)
            path.move(to: NSPoint(x: x, y: rect.minY))
            path.line(to: NSPoint(x: x, y: rect.maxY))
        }

        path.stroke()
    }

    private func drawYAxisLabels(in rect: NSRect) {
        let attrs = axisLabelAttributes()
        for pct in stride(from: 0.0, through: 100.0, by: 25.0) {
            let label = "\(Int(pct))%"
            let size = label.size(withAttributes: attrs)
            label.draw(
                at: NSPoint(x: rect.minX - size.width - 6, y: yFor(pct, in: rect) - size.height / 2),
                withAttributes: attrs
            )
        }
    }

    private func drawXAxisLabels(in rect: NSRect, start: Date, end: Date) {
        let totalSeconds = end.timeIntervalSince(start)
        let formatter = DateFormatter()
        if totalSeconds < 24 * 3600 {
            formatter.dateFormat = "HH:mm"
        } else if totalSeconds < 7 * 24 * 3600 {
            formatter.dateFormat = "EEE HH:mm"
        } else {
            formatter.dateFormat = "MMM d"
        }

        let attrs = axisLabelAttributes()
        let count = 5
        for i in 0...count {
            let date = start.addingTimeInterval(totalSeconds * Double(i) / Double(count))
            let label = formatter.string(from: date)
            let size = label.size(withAttributes: attrs)
            label.draw(
                at: NSPoint(x: xFor(date, in: rect, start: start, end: end) - size.width / 2, y: rect.minY - size.height - 4),
                withAttributes: attrs
            )
        }
    }

    private func axisLabelAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
    }

    private func drawArea(_ points: [ChartPoint], color: NSColor, in rect: NSRect, start: Date, end: Date) {
        guard points.count >= 2 else { return }

        let path = NSBezierPath()
        let firstX = xFor(points[0].date, in: rect, start: start, end: end)
        path.move(to: NSPoint(x: firstX, y: yFor(0, in: rect)))

        for point in points {
            path.line(to: NSPoint(x: xFor(point.date, in: rect, start: start, end: end), y: yFor(point.value, in: rect)))
        }

        path.line(to: NSPoint(x: xFor(points.last!.date, in: rect, start: start, end: end), y: yFor(0, in: rect)))
        path.close()

        color.withAlphaComponent(0.08).setFill()
        path.fill()
    }

    private func drawLine(_ points: [ChartPoint], color: NSColor, in rect: NSRect, start: Date, end: Date, dashed: Bool = false) {
        guard points.count >= 2 else { return }

        let path = NSBezierPath()
        path.lineWidth = dashed ? 1.5 : 2
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        if dashed {
            path.setLineDash([6, 4], count: 2, phase: 0)
        }

        for (i, point) in points.enumerated() {
            let p = NSPoint(x: xFor(point.date, in: rect, start: start, end: end), y: yFor(point.value, in: rect))
            if i == 0 { path.move(to: p) } else { path.line(to: p) }
        }

        color.setStroke()
        path.stroke()
    }

    private func drawNowMarker(in rect: NSRect, start: Date, end: Date) {
        let now = Date()
        guard now >= start, now <= end else { return }

        let x = xFor(now, in: rect, start: start, end: end)
        let path = NSBezierPath()
        path.lineWidth = 1
        path.setLineDash([3, 3], count: 2, phase: 0)
        path.move(to: NSPoint(x: x, y: rect.minY))
        path.line(to: NSPoint(x: x, y: rect.maxY))
        NSColor.tertiaryLabelColor.setStroke()
        path.stroke()
    }

    private func drawLegend(in rect: NSRect) {
        guard !series.isEmpty else { return }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        let dotSize: CGFloat = 8
        let dotSpacing: CGFloat = 6
        let entryGap: CGFloat = 16

        var totalWidth: CGFloat = 0
        for (i, s) in series.enumerated() {
            totalWidth += dotSize + dotSpacing + s.label.size(withAttributes: attrs).width
            if i < series.count - 1 { totalWidth += entryGap }
        }

        var x = rect.maxX - totalWidth
        let y = rect.maxY + 8

        for s in series {
            s.color.setFill()
            NSBezierPath(ovalIn: NSRect(x: x, y: y + 2, width: dotSize, height: dotSize)).fill()
            x += dotSize + dotSpacing

            s.label.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
            x += s.label.size(withAttributes: attrs).width + entryGap
        }
    }

    private func drawCenteredText(_ text: String, in rect: NSRect) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let size = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2), withAttributes: attrs)
    }
}
