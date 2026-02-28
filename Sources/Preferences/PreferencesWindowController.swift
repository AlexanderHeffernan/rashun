import Cocoa

@MainActor
final class PreferencesWindowController: NSWindowController {
    static let shared = PreferencesWindowController()

    private var currentSources: [AISource] = []

    private init() {
        let vc = NSViewController()
        vc.view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 320))

        let window = NSWindow(contentViewController: vc)
        window.title = "Preferences"
        window.styleMask = [.titled, .closable, .miniaturizable]

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func showWindowAndBringToFront() {
        self.window?.center()
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Configure the preferences window to display the provided sources.
    func configure(withSources sources: [AISource]) {
        currentSources = sources
        SettingsStore.shared.ensureSources(sources.map { $0.name })

        guard let vc = window?.contentViewController else { return }
        // Clear existing
        vc.view.subviews.forEach { $0.removeFromSuperview() }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let header = NSTextField(labelWithString: "Sources")
        header.font = NSFont.boldSystemFont(ofSize: 14)
        stack.addArrangedSubview(header)

        for source in sources {
            let checkbox = NSButton(checkboxWithTitle: source.name, target: self, action: #selector(toggleChanged(_:)))
            checkbox.identifier = NSUserInterfaceItemIdentifier(source.name)
            checkbox.state = SettingsStore.shared.isEnabled(sourceName: source.name) ? .on : .off
            stack.addArrangedSubview(checkbox)
        }

        vc.view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: vc.view.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: vc.view.topAnchor, constant: 20)
        ])
    }

    @objc private func toggleChanged(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else { return }
        let enabled = (sender.state == .on)

        // If enabling, show a confirmation alert with requirements
        if enabled {
            let req = currentSources.first(where: { $0.name == id })?.requirements ?? ""
            let alert = NSAlert()
            alert.messageText = "Enable \(id)?"
            alert.informativeText = req.isEmpty ? "Enable this source?" : req
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Enable")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                SettingsStore.shared.setEnabled(true, for: id)
            } else {
                // revert checkbox state
                sender.state = .off
                SettingsStore.shared.setEnabled(false, for: id)
            }
        } else {
            SettingsStore.shared.setEnabled(false, for: id)
        }
    }
}
