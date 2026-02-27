import Foundation

struct CopilotSource: AISource {
    let name = "Copilot"

    func fetchUsage() async throws -> UsageResult {
        let token = try getGhAuthToken()

        var request = URLRequest(url: URL(string: "https://api.github.com/copilot_internal/user")!)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "GitHubAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Bad status code"])
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let quotaSnapshots = json?["quota_snapshots"] as? [String: Any],
              let premium = quotaSnapshots["premium_interactions"] as? [String: Any],
              let remaining = premium["remaining"] as? Int,
              let entitlement = premium["entitlement"] as? Int else {
            throw NSError(domain: "GitHubAPI", code: -2, userInfo: [NSLocalizedDescriptionKey: "Missing/invalid fields"])
        }

        return UsageResult(remaining: Double(remaining), limit: Double(entitlement))
    }

    private func getGhAuthToken() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "gh auth token"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else {
            throw NSError(domain: "GitHubAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No token from gh"])
        }

        return token
    }
}
