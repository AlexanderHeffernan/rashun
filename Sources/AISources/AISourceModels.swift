import Foundation

struct SourceFetchErrorPresentation: Codable {
    let shortMessage: String
    let detailedMessage: String

    init(shortMessage: String, detailedMessage: String) {
        self.shortMessage = shortMessage
        self.detailedMessage = detailedMessage
    }
}

struct UsageResult: Codable {
    let remaining: Double
    let limit: Double
    let resetDate: Date?
    let cycleStartDate: Date?

    init(remaining: Double, limit: Double, resetDate: Date? = nil, cycleStartDate: Date? = nil) {
        self.remaining = remaining
        self.limit = limit
        self.resetDate = resetDate
        self.cycleStartDate = cycleStartDate
    }

    var percentRemaining: Double {
        guard limit > 0 else { return 0 }
        return (remaining / limit) * 100
    }

    var formatted: String {
        String(format: "%.1f%%", percentRemaining)
    }
}

struct AISourceMetric: Sendable, Hashable {
    let id: String
    let title: String
    let defaultEnabled: Bool

    init(id: String, title: String, defaultEnabled: Bool = true) {
        self.id = id
        self.title = title
        self.defaultEnabled = defaultEnabled
    }
}
