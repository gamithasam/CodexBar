import AppKit
import CodexBarCore

extension StatusItemController {
    func installFocusedAppProviderObservation() {
        guard !SettingsStore.isRunningTests else { return }
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(self.focusedApplicationDidChange(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil)
        self.synchronizeFocusedAppProviderSelection()
    }

    @objc private func focusedApplicationDidChange(_ notification: Notification) {
        guard self.focusedAppSelectionIsActive, !self.hasPreparedForAppShutdown,
              let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        else { return }
        self.handleFocusedApplication(bundleIdentifier: app.bundleIdentifier)
    }

    func synchronizeFocusedAppProviderSelection() {
        guard !self.hasPreparedForAppShutdown else { return }
        let active = self.settings.automaticProviderSelectionEnabled && self.shouldMergeIcons
        if active != self.focusedAppSelectionIsActive {
            self.focusedAppSelectionIsActive = active
            self.focusedAppSelection = FocusedAppProviderSelection()
            if active, !SettingsStore.isRunningTests {
                self
                    .handleFocusedApplication(bundleIdentifier: NSWorkspace.shared.frontmostApplication?
                        .bundleIdentifier)
            }
        }
        self.focusedAppSelection.reconcile(enabledProviders: self.focusedAppEnabledProviders)
    }

    private var focusedAppEnabledProviders: Set<UsageProvider> {
        Set(self.store.enabledFirstPartyProvidersForDisplay())
    }

    func handleFocusedApplication(bundleIdentifier: String?) {
        guard self.focusedAppSelectionIsActive else { return }
        let provider = self.focusedAppSelection.focus(
            bundleIdentifier: bundleIdentifier,
            ownBundleIdentifier: Bundle.main.bundleIdentifier,
            mappings: self.settings.appProviderMappings,
            enabledProviders: self.focusedAppEnabledProviders,
            menuIsOpen: !self.openMenus.isEmpty)
        self.applyFocusedAppProvider(provider)
    }

    func recordManualProviderSelection(_ provider: UsageProvider?) {
        guard self.focusedAppSelectionIsActive else { return }
        self.focusedAppSelection.recordManualSelection(provider: provider)
    }

    func shouldApplyManualProviderSelection(_ selection: ProviderSwitcherSelection) -> Bool {
        switch selection {
        case .overview:
            self.recordManualProviderSelection(nil)
            return !self.settings.mergedMenuLastSelectedWasOverview
        case let .provider(instanceID):
            self.recordManualProviderSelection(instanceID.firstPartyProvider)
            return self.settings.mergedMenuLastSelectedWasOverview || self.selectedMenuProvider != instanceID
        }
    }

    func applyPendingFocusedAppProviderSelection() {
        guard self.focusedAppSelectionIsActive, self.openMenus.isEmpty, !self.hasPreparedForAppShutdown else { return }
        let provider = self.focusedAppSelection.menuClosed(
            mappings: self.settings.appProviderMappings,
            enabledProviders: self.focusedAppEnabledProviders)
        self.applyFocusedAppProvider(provider)
    }

    private func applyFocusedAppProvider(_ provider: UsageProvider?) {
        guard let provider,
              self.selectedMenuProvider != provider.instanceID || self.settings.mergedMenuLastSelectedWasOverview
        else { return }
        self.selectedMenuProvider = provider.instanceID
        self.settings.mergedMenuLastSelectedWasOverview = false
        self.lastMenuProvider = provider.instanceID
        self.lastMergedSwitcherSelection = .provider(provider.instanceID)
        self.refreshProviderSelectionDependentUI()
    }
}
