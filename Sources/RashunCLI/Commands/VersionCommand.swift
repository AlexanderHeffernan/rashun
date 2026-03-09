import ArgumentParser
import Foundation
import RashunCore

struct VersionCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Show current version"
    )

    @Flag(name: .long, help: "Output machine-readable JSON")
    var json = false

    func run() throws {
        let version = Versioning.versionString()
        if json {
            struct VersionResponse: Encodable {
                let version: String
            }
            let data = try JSONEncoder().encode(VersionResponse(version: version))
            guard let output = String(data: data, encoding: .utf8) else {
                throw ExitCode.failure
            }
            print(output)
            return
        }

        print("Rashun v\(version)")
    }
}
