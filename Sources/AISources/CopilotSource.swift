import Foundation

struct CopilotSource: AISource {
    let name = "Copilot"
    let requirements = "Requires GitHub CLI 'gh' configured and authenticated (used to fetch auth token)."

    var customNotificationDefinitions: [NotificationDefinition] {
        [behindPaceRule()]
    }

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

    func forecast(current: UsageResult, history: [UsageSnapshot]) -> ForecastResult? {
        let now = Date()
        let utc = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc

        let yearMonth = calendar.dateComponents([.year, .month], from: now)
        guard let cycleStart = calendar.date(from: DateComponents(
            timeZone: utc,
            year: yearMonth.year,
            month: yearMonth.month,
            day: 1,
            hour: 0,
            minute: 0,
            second: 0
        )),
        let resetDate = calendar.date(byAdding: .month, value: 1, to: cycleStart) else {
            return nil
        }

        let currentPercent = min(max(current.percentRemaining, 0), 100)
        let usedPercentSoFar = 100 - currentPercent
        let elapsedSinceCycleStart = max(now.timeIntervalSince(cycleStart), 1)
        let burnRatePerSecond = usedPercentSoFar > 0 ? (usedPercentSoFar / elapsedSinceCycleStart) : 0

        let resetFormatter = DateFormatter()
        resetFormatter.timeZone = utc
        resetFormatter.dateFormat = "MMM d, HH:mm 'UTC'"

        let preReset = resetDate.addingTimeInterval(-1)
        var points: [ForecastPoint] = [ForecastPoint(date: now, value: currentPercent)]

        let projectedPreReset: Double
        if burnRatePerSecond > 0 {
            let secondsToPreReset = max(0, preReset.timeIntervalSince(now))
            let secondsToZero = currentPercent / burnRatePerSecond
            let projectionHorizon = min(secondsToPreReset, secondsToZero)
            let steps = max(12, min(80, Int(projectionHorizon / 3600)))

            for index in 1...steps {
                let fraction = Double(index) / Double(steps)
                let date = now.addingTimeInterval(projectionHorizon * fraction)
                let value = max(currentPercent - burnRatePerSecond * date.timeIntervalSince(now), 0)
                points.append(ForecastPoint(date: date, value: value))
            }

            if secondsToZero < secondsToPreReset {
                points.append(ForecastPoint(date: preReset, value: 0))
            }

            projectedPreReset = max(currentPercent - burnRatePerSecond * secondsToPreReset, 0)
        } else {
            projectedPreReset = currentPercent
            if preReset > now {
                points.append(ForecastPoint(date: preReset, value: currentPercent))
            }
        }

        points.append(ForecastPoint(date: resetDate, value: projectedPreReset))
        points.append(ForecastPoint(date: resetDate, value: 100))

        let summary: String
        if burnRatePerSecond > 0 {
            let secondsToZero = currentPercent / burnRatePerSecond
            let zeroDate = now.addingTimeInterval(secondsToZero)
            if secondsToZero.isFinite, zeroDate > now, zeroDate < resetDate {
                summary = "Copilot: projected 0% by \(resetFormatter.string(from: zeroDate)); resets \(resetFormatter.string(from: resetDate))"
            } else {
                summary = "Copilot: projected \(String(format: "%.0f", projectedPreReset))% at reset (\(resetFormatter.string(from: resetDate)))"
            }
        } else {
            summary = "Copilot: resets \(resetFormatter.string(from: resetDate))"
        }

        return ForecastResult(points: points, summary: summary)
    }

    private func getGhAuthToken() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/gh")
        process.arguments = ["auth", "token"]
        process.currentDirectoryURL = URL(fileURLWithPath: "/")

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

    private func behindPaceRule() -> NotificationDefinition {
        NotificationDefinition(
            id: "behindPace",
            title: "Monthly pacing alert",
            detail: "Notifies if your usage is on track to run out before the month ends. Tolerance sets how many extra percentage points over the ideal pace are allowed.",
            inputs: [
                NotificationInputSpec(
                    id: "drift",
                    label: "Tolerance",
                    unit: "%",
                    defaultValue: 5,
                    min: 0,
                    max: 50,
                    step: 1
                )
            ],
            evaluate: { context in
                let drift = context.value(for: "drift", defaultValue: 5)

                let calendar = Calendar.current
                let now = Date()
                let day = calendar.component(.day, from: now)
                guard let range = calendar.range(of: .day, in: .month, for: now) else { return nil }
                let daysInMonth = range.count

                let used = 100 - context.current.percentRemaining
                let expectedUsed = 100 * (Double(day) / Double(daysInMonth))

                let isBehind = used > (expectedUsed + drift)
                let wasBehind: Bool
                if let prev = context.previous?.usage.percentRemaining {
                    let prevUsed = 100 - prev
                    wasBehind = prevUsed > (expectedUsed + drift)
                } else {
                    wasBehind = false
                }

                guard isBehind, !wasBehind else { return nil }

                let title = "Copilot pacing alert"
                let body = "You're using Copilot faster than your monthly allowance. \(String(format: "%.0f", used))% used by day \(day)/\(daysInMonth) — ideally you'd be at \(String(format: "%.0f", expectedUsed))%."
                return NotificationEvent(title: title, body: body, cooldownSeconds: 86400, cycleKey: nil)
            }
        )
    }
}
