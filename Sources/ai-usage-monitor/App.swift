import Cocoa
import UserNotifications

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let app = NSApplication.shared
    var statusItem: NSStatusItem?
    var menu: NSMenu?
    
    var copilotRemaining: String = "N/A"  // Changed to String to match your % display
    var ampUsage: String = "N/A"  // Changed to Double to match your % display

    func applicationDidFinishLaunching(_: Notification) {
        print("App launched - setting up status item")

        // Remove or comment these lines for now:
        // UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        // Or wrap if you want to keep for future:
        // if #available(macOS 10.14, *) {
        //     UNUserNotificationCenter.current().requestAuthorization(...) { ... }
        // }

        // Rest of your setup...
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.title = "AI"
            print("Status item button title set to 'AI'")
        }

        menu = NSMenu()
        statusItem?.menu = menu

        updateMenu()

        Task { await refresh() }  // Or DispatchQueue.global().async { self.refresh() } if no async needed yet

        app.run()
    }

    @objc func quit() {
        app.terminate(nil)
    }

    func updateMenu() {
        menu?.removeAllItems()
        menu?.addItem(withTitle: "Copilot Remaining: \(copilotRemaining)", action: nil, keyEquivalent: "")
        menu?.addItem(withTitle: "AMP Remaining: \(ampUsage)", action: nil, keyEquivalent: "")
        menu?.addItem(NSMenuItem.separator())
        menu?.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
    }

    func refresh() async {
        do {
            let copilotData = try await fetchCopilotUsage()
            copilotRemaining = String(format: "%.1f%%", copilotData.percentRemaining)
        } catch {
            print("Copilot fetch error: \(error)")
            copilotRemaining = "Error"
        }

        do {
            let output = try await runAmpUsageCommand()
            if let percentage = parseAmpFreePercentage(from: output) {
                ampUsage = String(format: "%.1f%%", percentage)
            } else {
                ampUsage = "Parse error"
            }
        } catch {
            print("Amp fetch error: \(error)")
            ampUsage = "Error"
        }

        updateMenu()
    }

    // ────────────────────────────────────────────────
    // New helper functions — add at the bottom of the class
    // ────────────────────────────────────────────────

    private func fetchCopilotUsage() async throws -> CopilotQuota {
        // Get GitHub token from gh CLI (same as your curl)
        let token = try await getGhAuthToken()

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
            let entitlement = premium["entitlement"] as? Int,
            let percent = premium["percent_remaining"] as? Double else {
            throw NSError(domain: "GitHubAPI", code: -2, userInfo: [NSLocalizedDescriptionKey: "Missing/invalid fields"])
        }

        return CopilotQuota(remaining: remaining, entitlement: entitlement, percentRemaining: percent)
    }

    private struct CopilotQuota {
        let remaining: Int
        let entitlement: Int
        let percentRemaining: Double
    }

    private func getGhAuthToken() async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh", "auth", "token"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()  // ignore errors for now

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !token.isEmpty else {
            throw NSError(domain: "GitHubAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No token from gh"])
        }

        return token
    }

    private func runAmpUsageCommand() async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["amp", "usage"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe  // Capture errors too

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

    private func parseAmpFreePercentage(from output: String) -> Double? {
        let pattern = #"Amp Free: \$([\d.]+)/\$([\d.]+) remaining"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(output.startIndex..., in: output)
        guard let match = regex.firstMatch(in: output, range: range),
              match.numberOfRanges == 3,
              let currentRange = Range(match.range(at: 1), in: output),
              let limitRange = Range(match.range(at: 2), in: output) else {
            return nil
        }

        guard let current = Double(output[currentRange]),
              let limit = Double(output[limitRange]),
              limit > 0 else {
            return nil
        }

        return (current / limit) * 100
    }
}

// Set up and run
let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()