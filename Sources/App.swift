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
            button.title = "AI"
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
        for source in enabled {
            loadingSources.insert(source.name)
        }
        updateMenu()

        for source in enabled {
            do {
                let usage = try await source.fetchUsage()
                results[source.name] = usage.formatted
            } catch {
                print("\(source.name) fetch error: \(error)")
                results[source.name] = "Error"
            }
            loadingSources.remove(source.name)
            updateMenu()
        }

        updateMenu()
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
