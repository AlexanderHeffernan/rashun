import Foundation

struct AmpSource: AISource {
    let name = "AMP"

    func fetchUsage() async throws -> UsageResult {
        let output = try runCommand()
        guard let result = parseUsage(from: output) else {
            throw NSError(domain: "AmpError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse: \(output)"])
        }
        return result
    }

    private func runCommand() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: NSHomeDirectory() + "/.amp/bin/amp")
        process.arguments = ["usage"]
        process.currentDirectoryURL = URL(fileURLWithPath: "/")

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw NSError(domain: "AmpError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No output"])
        }

        if process.terminationStatus != 0 {
            throw NSError(domain: "AmpError", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: output])
        }

        return output
    }

    private func parseUsage(from output: String) -> UsageResult? {
        let pattern = #"Amp Free: \$([\d.]+)/\$([\d.]+) remaining"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(output.startIndex..., in: output)
        guard let match = regex.firstMatch(in: output, range: range),
              match.numberOfRanges == 3,
              let currentRange = Range(match.range(at: 1), in: output),
              let limitRange = Range(match.range(at: 2), in: output) else {
            return nil
        }

        guard let remaining = Double(output[currentRange]),
              let limit = Double(output[limitRange]) else {
            return nil
        }

        return UsageResult(remaining: remaining, limit: limit)
    }
}
