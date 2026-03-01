import Foundation

enum NotificationDefinitions {
    static func generic(sourceName: String) -> [NotificationDefinition] {
        let percentRemainingBelow = NotificationDefinition(
            id: "percentRemainingBelow",
            title: "Percent remaining below",
            detail: "Notifies when remaining percent drops below your threshold.",
            inputs: [
                NotificationInputSpec(
                    id: "threshold",
                    label: "Threshold",
                    unit: "%",
                    defaultValue: 50,
                    min: 1,
                    max: 99,
                    step: 1
                )
            ],
            evaluate: { context in
                let threshold = context.value(for: "threshold", defaultValue: 50)
                let current = context.current.percentRemaining
                let previous = context.previous?.usage.percentRemaining

                guard current < threshold else { return nil }
                if let prev = previous, prev < threshold {
                    return nil
                }

                let title = "\(sourceName) usage alert"
                let body = "Remaining is now \(String(format: "%.0f", current))%, below \(String(format: "%.0f", threshold))%."
                return NotificationEvent(title: title, body: body, cooldownSeconds: 3600, cycleKey: nil)
            }
        )

        let recentSpike = NotificationDefinition(
            id: "recentUsageSpike",
            title: "Recent usage spike",
            detail: "Notifies when usage drops quickly within a time window.",
            inputs: [
                NotificationInputSpec(
                    id: "dropPercent",
                    label: "Drop",
                    unit: "%",
                    defaultValue: 10,
                    min: 1,
                    max: 100,
                    step: 1
                ),
                NotificationInputSpec(
                    id: "minutes",
                    label: "Window",
                    unit: "min",
                    defaultValue: 30,
                    min: 2,
                    max: 240,
                    step: 1
                )
            ],
            evaluate: { context in
                let drop = context.value(for: "dropPercent", defaultValue: 10)
                let minutes = context.value(for: "minutes", defaultValue: 30)
                guard let past = context.snapshot(minutesAgo: minutes) else { return nil }

                let current = context.current.percentRemaining
                let previous = past.usage.percentRemaining
                let used = max(0, previous - current)
                guard used >= drop else { return nil }

                let title = "\(sourceName) usage spike"
                let body = "You used about \(String(format: "%.0f", used))% in the last \(Int(minutes)) minutes."
                return NotificationEvent(title: title, body: body, cooldownSeconds: 3600, cycleKey: nil)
            }
        )

        return [percentRemainingBelow, recentSpike]
    }
}
