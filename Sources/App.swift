import Cocoa

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem?
    var menu: NSMenu?
    var pollTimer: Timer?

    let pollInterval: TimeInterval = 600 // seconds (10 minutes)
    let loadingIndicator = "⏳"

    var sources: [AISource] { allSources }

    var results: [String: String] = [:]
    var loadingSources: Set<String> = []

    func applicationDidFinishLaunching(_: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // try to use an SF Symbol brain icon (template) and show a placeholder title
            if let brain = NSImage(systemSymbolName: "brain", accessibilityDescription: "AI") {
                brain.isTemplate = true
                button.image = brain
                button.imagePosition = .imageLeft
            } else {
                button.title = "AI"
            }
            button.title = "—"
        }

        menu = NSMenu()
        menu?.delegate = self
        statusItem?.menu = menu

        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged(_:)), name: .aiSettingsChanged, object: nil)

        SettingsStore.shared.ensureSources(sources.map { $0.name })
        updateMenu()

        Task {
            _ = await NotificationManager.shared.requestAuthorization()
            await refresh()
        }

        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.refresh() }
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        Task { await refresh() }
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }

    func updateMenu() {
        menu?.removeAllItems()
        let enabled = sources.filter { SettingsStore.shared.isEnabled(sourceName: $0.name) }
        if enabled.isEmpty {
            menu?.addItem(withTitle: "No sources enabled — open Settings...", action: #selector(showPreferences), keyEquivalent: "")
        } else {
            for source in enabled {
                let display = loadingSources.contains(source.name)
                    ? loadingIndicator
                    : (results[source.name] ?? "N/A")
                menu?.addItem(withTitle: "\(source.name) Remaining: \(display)", action: nil, keyEquivalent: "")
            }
        }
        menu?.addItem(NSMenuItem.separator())
        menu?.addItem(withTitle: "Settings...", action: #selector(showPreferences), keyEquivalent: ",")
        menu?.addItem(NSMenuItem.separator())
        menu?.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
    }

    @objc func showPreferences() {
        PreferencesWindowController.shared.configure(withSources: sources)
        PreferencesWindowController.shared.showWindowAndBringToFront()
    }

    func refresh() async {
        guard loadingSources.isEmpty else { return }
        let enabled = sources.filter { SettingsStore.shared.isEnabled(sourceName: $0.name) }
        for source in enabled { loadingSources.insert(source.name) }
        updateMenu()

        var percentValues: [Double] = []

        await withTaskGroup(of: (String, UsageResult?).self) { group in
            for source in enabled {
                group.addTask {
                    let res = try? await source.fetchUsage()
                    return (source.name, res)
                }
            }

            for await (name, res) in group {
                if let usage = res {
                    results[name] = usage.formatted
                    let p = min(max(usage.percentRemaining, 0), 100)
                    percentValues.append(p)
                } else {
                    results[name] = "Error"
                }
                loadingSources.remove(name)
                updateMenu()
            }
        }

        // compute average remaining percentage across successful sources
        if percentValues.isEmpty {
            // no successful sources to aggregate
            if let button = statusItem?.button {
                button.title = "—"
                if let outline = NSImage(systemSymbolName: "brain", accessibilityDescription: nil) {
                    outline.isTemplate = true
                    button.image = outline
                }
            }
        } else {
            let avg = percentValues.reduce(0, +) / Double(percentValues.count)
            let formatted = String(format: "%.0f%%", avg)
            if let button = statusItem?.button {
                button.title = formatted
                if let img = brainFillImage(percent: avg, size: NSSize(width: 16, height: 16)) {
                    button.image = img
                    button.imagePosition = .imageLeft
                }
            }
        }
    }

    /// Generate a template NSImage representing the brain with the bottom `percent` filled.
    /// `percent` is 0..100. Returns a template image so the system tints it for the menu bar.
    private func brainFillImage(percent: Double, size: NSSize) -> NSImage? {
        guard let fill = NSImage(systemSymbolName: "brain.fill", accessibilityDescription: nil),
              let outline = NSImage(systemSymbolName: "brain", accessibilityDescription: nil) else {
            return nil
        }

        let image = NSImage(size: size)
        image.isTemplate = true

        image.lockFocus()
        defer { image.unlockFocus() }

        guard let ctx = NSGraphicsContext.current?.cgContext else { return nil }

        let bounds = CGRect(origin: .zero, size: size)

        // Draw the filled brain clipped to the bottom percent
        ctx.saveGState()
        let clippedHeight = bounds.height * CGFloat(min(max(percent, 0), 100) / 100.0)
        let fillClipRect = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: clippedHeight)
        ctx.clip(to: fillClipRect)
        fill.draw(in: bounds)
        ctx.restoreGState()

        // Draw the outline clipped to the top (unfilled) portion so it visually shows the empty area
        ctx.saveGState()
        let outlineClipRect = CGRect(x: bounds.minX, y: bounds.minY + clippedHeight, width: bounds.width, height: bounds.height - clippedHeight)
        ctx.clip(to: outlineClipRect)
        outline.draw(in: bounds)
        ctx.restoreGState()

        return image
    }

    @objc private func settingsChanged(_ note: Notification) {
        let enabled = Set(sources.filter { SettingsStore.shared.isEnabled(sourceName: $0.name) }.map { $0.name })
        // prune results for disabled sources
        results = results.filter { enabled.contains($0.key) }
        updateMenu()
    }
}

@main
enum Main {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
