import Foundation

struct UsageResult {
    let remaining: Double
    let limit: Double

    var percentRemaining: Double {
        guard limit > 0 else { return 0 }
        return (remaining / limit) * 100
    }

    var formatted: String {
        String(format: "%.1f%%", percentRemaining)
    }
}

protocol AISource: Sendable {
    // Unique name for this source (shown in menu and settings)
    var name: String { get }
    /// Human-readable requirements or hints for using this source (shown in Preferences)
    var requirements: String { get }
    func fetchUsage() async throws -> UsageResult
}

extension AISource {
    var requirements: String { "" }
}
