import Cocoa

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem?
    var menu: NSMenu?
    var pollTimer: Timer?

    let pollInterval: TimeInterval = 600 // seconds (10 minutes)
    let loadingIndicator = "⏳"

    let sources: [AISource] = [
        CopilotSource(),
        AmpSource(),
    ]

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

        updateMenu()

        Task { await refresh() }

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
        for source in sources {
            let display = loadingSources.contains(source.name)
                ? loadingIndicator
                : (results[source.name] ?? "N/A")
            menu?.addItem(withTitle: "\(source.name) Remaining: \(display)", action: nil, keyEquivalent: "")
        }
        menu?.addItem(NSMenuItem.separator())
        menu?.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
    }

    func refresh() async {
        guard loadingSources.isEmpty else { return }

        for source in sources {
            loadingSources.insert(source.name)
        }
        updateMenu()

        for source in sources {
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
