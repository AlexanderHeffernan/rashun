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
    var name: String { get }
    func fetchUsage() async throws -> UsageResult
}
