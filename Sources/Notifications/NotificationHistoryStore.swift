import Foundation

@MainActor
final class NotificationHistoryStore {
    static let shared = NotificationHistoryStore()
    private init() { load() }

    private let maxSnapshots = 120
    private let userDefaultsKey = "ai.notificationHistory.v1"
    private var historyBySource: [String: [UsageSnapshot]] = [:]

    func history(for sourceName: String) -> [UsageSnapshot] {
        historyBySource[sourceName] ?? []
    }

    func append(sourceName: String, usage: UsageResult) {
        var history = historyBySource[sourceName] ?? []
        history.append(UsageSnapshot(timestamp: Date(), usage: usage))
        if history.count > maxSnapshots {
            history.removeFirst(history.count - maxSnapshots)
        }
        historyBySource[sourceName] = history
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([String: [UsageSnapshot]].self, from: data) else { return }
        historyBySource = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(historyBySource) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
