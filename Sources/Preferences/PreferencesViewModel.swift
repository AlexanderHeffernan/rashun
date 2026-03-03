import SwiftUI
import ServiceManagement

@MainActor
final class PreferencesViewModel: ObservableObject {
    @Published private(set) var sources: [AISource] = []
    @Published var expandedSources: Set<String> = []
    @Published var pendingEnableSource: AISource?
    @Published var showInstallConfirmation = false
    @Published var pollMinutesText = ""
    @Published var ruleInputDrafts: [String: String] = [:]
    @Published private(set) var checkNowEnabled = true
    @Published private(set) var installEnabled = true
    @Published private(set) var updateStatusText = ""
    @Published private(set) var updateStatusIsPositive = false
    @Published var launchAtLoginErrorMessage: String?

    init() {
        registerObservers()
        pollMinutesText = formattedPollMinutes()
        refreshUpdateStatus()
    }

    func configure(withSources newSources: [AISource]) {
        sources = newSources
        SettingsStore.shared.ensureSources(newSources.map { $0.name })

        for source in newSources {
            SettingsStore.shared.ensureNotificationRules(source: source)
            if !SettingsStore.shared.isEnabled(sourceName: source.name) {
                expandedSources.remove(source.name)
            }
            seedRuleInputDrafts(for: source)
        }

        pollMinutesText = formattedPollMinutes()
        refreshUpdateStatus()
        objectWillChange.send()
    }

    func isSourceEnabled(_ sourceName: String) -> Bool {
        SettingsStore.shared.isEnabled(sourceName: sourceName)
    }

    func sourceToggleChanged(_ source: AISource, enabled: Bool) {
        if enabled {
            pendingEnableSource = source
            return
        }

        expandedSources.remove(source.name)
        SettingsStore.shared.setEnabled(false, for: source.name)
    }

    func confirmEnableSource() {
        guard let source = pendingEnableSource else { return }
        SettingsStore.shared.setEnabled(true, for: source.name)
        pendingEnableSource = nil
    }

    func cancelEnableSource() {
        pendingEnableSource = nil
    }

    func isSourceExpanded(_ sourceName: String) -> Bool {
        expandedSources.contains(sourceName)
    }

    func toggleNotificationsSection(_ sourceName: String) {
        if expandedSources.contains(sourceName) {
            expandedSources.remove(sourceName)
        } else {
            expandedSources.insert(sourceName)
        }
    }

    func isRuleEnabled(sourceName: String, ruleId: String) -> Bool {
        SettingsStore.shared.ruleSettings(for: sourceName).first(where: { $0.ruleId == ruleId })?.isEnabled ?? false
    }

    func setRuleEnabled(sourceName: String, ruleId: String, enabled: Bool) {
        SettingsStore.shared.setRuleEnabled(enabled, sourceName: sourceName, ruleId: ruleId)
    }

    func ruleInputText(sourceName: String, ruleId: String, input: NotificationInputSpec) -> String {
        let key = inputKey(sourceName: sourceName, ruleId: ruleId, inputId: input.id)
        if let draft = ruleInputDrafts[key] {
            return draft
        }

        let value = SettingsStore.shared.ruleInputValue(
            sourceName: sourceName,
            ruleId: ruleId,
            inputId: input.id,
            defaultValue: input.defaultValue
        )
        return String(format: "%.0f", value)
    }

    func setRuleInputDraft(sourceName: String, ruleId: String, inputId: String, text: String) {
        ruleInputDrafts[inputKey(sourceName: sourceName, ruleId: ruleId, inputId: inputId)] = text
    }

    func commitRuleInput(sourceName: String, ruleId: String, input: NotificationInputSpec) {
        let key = inputKey(sourceName: sourceName, ruleId: ruleId, inputId: input.id)
        let draft = ruleInputDrafts[key] ?? ""

        guard let parsed = Double(draft) else {
            let current = SettingsStore.shared.ruleInputValue(
                sourceName: sourceName,
                ruleId: ruleId,
                inputId: input.id,
                defaultValue: input.defaultValue
            )
            ruleInputDrafts[key] = String(format: "%.0f", current)
            return
        }

        let clamped = min(max(parsed, input.min), input.max)
        SettingsStore.shared.setRuleValue(clamped, sourceName: sourceName, ruleId: ruleId, inputId: input.id)
        ruleInputDrafts[key] = String(format: "%.0f", clamped)
    }

    func flushPendingEdits() {
        applyPollInterval()

        for source in sources {
            for definition in source.notificationDefinitions {
                for input in definition.inputs {
                    commitRuleInput(sourceName: source.name, ruleId: definition.id, input: input)
                }
            }
        }
    }

    var autoUpdateCheckEnabled: Bool {
        get { SettingsStore.shared.autoUpdateCheckEnabled }
        set { SettingsStore.shared.setAutoUpdateCheckEnabled(newValue) }
    }

    var launchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        launchAtLoginErrorMessage = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            objectWillChange.send()
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 150_000_000)
                self?.objectWillChange.send()
            }
        } catch {
            launchAtLoginErrorMessage = "Could not update Launch at Login. \(error.localizedDescription)"
            objectWillChange.send()
        }
    }

    func applyPollInterval() {
        guard let minutes = Double(pollMinutesText), minutes > 0 else {
            pollMinutesText = formattedPollMinutes()
            return
        }

        SettingsStore.shared.setPollIntervalSeconds(minutes * 60)
        pollMinutesText = formattedPollMinutes()
    }

    func checkForUpdates() async {
        _ = await UpdateManager.shared.checkForUpdate(notify: false)
        refreshUpdateStatus()
        objectWillChange.send()
    }

    func installUpdate() {
        UpdateManager.shared.installUpdate()
        showInstallConfirmation = false
    }

    var updateStatusColor: Color {
        if updateStatusIsPositive { return BrandPalette.accent }
        if updateStatusText.isEmpty { return BrandPalette.textSecondary }
        return BrandPalette.warning
    }

    var updateAvailable: Bool {
        UpdateManager.shared.updateAvailable
    }

    var currentVersionText: String {
        "Current version: \(UpdateManager.shared.currentVersion)"
    }

    var availableVersionText: String {
        UpdateManager.shared.availableVersion ?? ""
    }

    var pendingEnableMessage: String {
        guard let source = pendingEnableSource else { return "" }
        return source.requirements.isEmpty ? "Enable this source?" : source.requirements
    }

    private func registerObservers() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(handleSettingsChanged), name: .aiSettingsChanged, object: nil)
        center.addObserver(self, selector: #selector(handleUpdateStatusChanged), name: .updateStatusChanged, object: nil)
    }

    @objc private func handleSettingsChanged() {
        pollMinutesText = formattedPollMinutes()
        objectWillChange.send()
    }

    @objc private func handleUpdateStatusChanged() {
        refreshUpdateStatus()
    }

    private func seedRuleInputDrafts(for source: AISource) {
        for definition in source.notificationDefinitions {
            for input in definition.inputs {
                let key = inputKey(sourceName: source.name, ruleId: definition.id, inputId: input.id)
                if ruleInputDrafts[key] != nil { continue }

                let value = SettingsStore.shared.ruleInputValue(
                    sourceName: source.name,
                    ruleId: definition.id,
                    inputId: input.id,
                    defaultValue: input.defaultValue
                )
                ruleInputDrafts[key] = String(format: "%.0f", value)
            }
        }
    }

    private func formattedPollMinutes() -> String {
        String(format: "%.0f", SettingsStore.shared.pollInterval() / 60)
    }

    private func refreshUpdateStatus() {
        if UpdateManager.shared.isInstalling {
            updateStatusText = "Installing..."
            checkNowEnabled = false
            installEnabled = false
            updateStatusIsPositive = false
        } else if UpdateManager.shared.isChecking {
            updateStatusText = "Checking..."
            checkNowEnabled = false
            installEnabled = true
            updateStatusIsPositive = false
        } else if UpdateManager.shared.updateAvailable {
            updateStatusText = "Version \(UpdateManager.shared.availableVersion ?? "") available"
            checkNowEnabled = true
            installEnabled = true
            updateStatusIsPositive = true
        } else if UpdateManager.shared.availableVersion != nil {
            updateStatusText = "Up to date"
            checkNowEnabled = true
            installEnabled = true
            updateStatusIsPositive = true
        } else {
            updateStatusText = ""
            checkNowEnabled = true
            installEnabled = true
            updateStatusIsPositive = false
        }
    }

    private func inputKey(sourceName: String, ruleId: String, inputId: String) -> String {
        "\(sourceName)|\(ruleId)|\(inputId)"
    }
}
