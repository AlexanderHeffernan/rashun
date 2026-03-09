import ArgumentParser
import Foundation
import RashunCore

@main
struct RashunCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rashun",
        abstract: "AI usage monitor CLI",
        discussion: "Run `rashun --help` to see all commands.",
        subcommands: [VersionCommand.self]
    )

    func run() async throws {
        print("Rashun v\(Versioning.versionString()) -- AI Usage Monitor")
        print("")
        print("Quick start:")
        print("  rashun sources          See available AI sources and setup status")
        print("  rashun check <source>   Verify a source is configured correctly")
        print("  rashun status <source>  Check current usage for a source")
        print("  rashun status           Check usage for all active sources")
        print("  rashun --help           See all commands")
        print("")
        let sourceNames = allSources.map(\.name).joined(separator: ", ")
        print("Supported sources: \(sourceNames)")
    }
}
