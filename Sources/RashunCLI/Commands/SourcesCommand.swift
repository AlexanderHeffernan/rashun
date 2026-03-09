import ArgumentParser
import Foundation
import RashunCore

struct SourcesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sources",
        abstract: "List available sources and setup status"
    )

    @OptionGroup
    var global: GlobalOptions

    @MainActor
    func run() async throws {
        let sources = allSources

        if global.json {
            try JSONOutput.print(sources.map(makeJSONEntry(for:)))
            return
        }

        let formatter = OutputFormatter(noColor: global.noColor)
        print("Available sources:")
        print("")
        for source in sources {
            let health = SourceHealthStore.shared.health(for: source.name)
            let healthy = (health?.consecutiveFailures ?? 0) == 0
            let hasHealthRecord = health != nil
            let symbol = healthy
                ? formatter.emoji("✅", fallback: "[ok]")
                : formatter.emoji("❌", fallback: "[x]")

            let displayName = healthy
                ? formatter.colorize(source.name, as: .magenta)
                : formatter.colorize(source.name, as: .yellow)

            let statusText = healthy
                ? "ready"
                : "needs attention"

            let statusColor: OutputFormatter.ANSIColor = healthy ? .cyan : .yellow

            print("  \(symbol) \(displayName)  \(formatter.colorize(statusText, as: statusColor))")
            if !hasHealthRecord {
                print("     Tip: run `rashun check \(source.name)` to verify setup.")
            }
            if let message = health?.shortErrorMessage, !message.isEmpty {
                print("     Last error: \(message)")
            }
            print("")
        }
    }

    @MainActor
    private func makeJSONEntry(for source: AISource) -> SourceEntry {
        let health = SourceHealthStore.shared.health(for: source.name)
        return SourceEntry(
            name: source.name,
            requirements: source.requirements,
            metrics: source.metrics.map { MetricEntry(id: $0.id, title: $0.title) },
            healthy: (health?.consecutiveFailures ?? 0) == 0,
            hasHealthRecord: health != nil,
            lastError: health?.shortErrorMessage
        )
    }
}

private struct SourceEntry: Encodable {
    let name: String
    let requirements: String
    let metrics: [MetricEntry]
    let healthy: Bool
    let hasHealthRecord: Bool
    let lastError: String?
}

private struct MetricEntry: Encodable {
    let id: String
    let title: String
}
