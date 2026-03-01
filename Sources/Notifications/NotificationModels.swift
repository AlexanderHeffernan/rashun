import Foundation

struct NotificationInputSpec {
    let id: String
    let label: String
    let unit: String?
    let defaultValue: Double
    let min: Double
    let max: Double
    let step: Double
}

struct NotificationDefinition {
    let id: String
    let title: String
    let detail: String
    let inputs: [NotificationInputSpec]
    let evaluate: (NotificationContext) -> NotificationEvent?
}

struct NotificationEvent {
    let title: String
    let body: String
    let cooldownSeconds: TimeInterval?
    let cycleKey: String?
}

struct UsageSnapshot: Codable {
    let timestamp: Date
    let usage: UsageResult
}

struct NotificationContext {
    let sourceName: String
    let current: UsageResult
    let previous: UsageSnapshot?
    let history: [UsageSnapshot]
    let inputValue: (String, Double) -> Double

    func value(for inputId: String, defaultValue: Double) -> Double {
        inputValue(inputId, defaultValue)
    }

    func snapshot(minutesAgo: Double) -> UsageSnapshot? {
        guard minutesAgo > 0 else { return nil }
        let target = Date().addingTimeInterval(-minutesAgo * 60)
        return history.last(where: { $0.timestamp <= target })
    }
}
