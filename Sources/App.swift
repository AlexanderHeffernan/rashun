import Cocoa

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var menu: NSMenu?

    let sources: [AISource] = [
        CopilotSource(),
        AmpSource(),
    ]

    var results: [String: String] = [:]

    func applicationDidFinishLaunching(_: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.title = "AI"
        }

        menu = NSMenu()
        statusItem?.menu = menu

        updateMenu()

        Task { await refresh() }
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }

    func updateMenu() {
        menu?.removeAllItems()
        for source in sources {
            let display = results[source.name] ?? "N/A"
            menu?.addItem(withTitle: "\(source.name) Remaining: \(display)", action: nil, keyEquivalent: "")
        }
        menu?.addItem(NSMenuItem.separator())
        menu?.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
    }

    func refresh() async {
        for source in sources {
            do {
                let usage = try await source.fetchUsage()
                results[source.name] = usage.formatted
            } catch {
                print("\(source.name) fetch error: \(error)")
                results[source.name] = "Error"
            }
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
