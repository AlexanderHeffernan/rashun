import Foundation

@MainActor
final class SettingsStore {
    static let shared = SettingsStore()
    private init() { load() }

    private let userDefaultsKey = "ai.sourceSettings.v1"
    private var enabledMap: [String: Bool] = [:]

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        if let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) {
            enabledMap = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(enabledMap) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    func isEnabled(sourceName: String) -> Bool {
        return enabledMap[sourceName] ?? false
    }

    func setEnabled(_ enabled: Bool, for sourceName: String) {
        enabledMap[sourceName] = enabled
        save()
        NotificationCenter.default.post(name: .aiSettingsChanged, object: nil)
    }

    /// Ensure keys exist for provided sources; does not override existing settings.
    func ensureSources(_ sourceNames: [String]) {
        for name in sourceNames where enabledMap[name] == nil {
            enabledMap[name] = false
        }
        save()
    }
}

extension Notification.Name {
    static let aiSettingsChanged = Notification.Name("ai.settings.changed")
}
