import AppKit
import CodexBarCore

extension StatusItemController {
    func selectMenuProviderManually(_ provider: ProviderInstanceID) {
        self.focusedAppProviderSelection.recordManualSelection()
        self.selectedMenuProvider = provider
    }

    func synchronizeFocusedAppProviderSelectionObservation() {
        let shouldObserve = self.settings.autoSelectProviderForFocusedApp && self.shouldMergeIcons
        guard shouldObserve else {
            if self.focusedAppActivationObserverInstalled {
                NSWorkspace.shared.notificationCenter.removeObserver(
                    self,
                    name: NSWorkspace.didActivateApplicationNotification,
                    object: nil)
                self.focusedAppActivationObserverInstalled = false
            }
            self.focusedAppProviderSelection.reset()
            return
        }
        guard !self.focusedAppActivationObserverInstalled else { return }

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(self.handleFocusedAppActivationNotification(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil)
        self.focusedAppActivationObserverInstalled = true
        self.handleFocusedAppActivation(bundleIdentifier: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    }

    @objc private func handleFocusedAppActivationNotification(_ notification: Notification) {
        let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        self.handleFocusedAppActivation(bundleIdentifier: application?.bundleIdentifier)
    }

    func handleFocusedAppActivation(bundleIdentifier: String?) {
        let enabledProviders = Set(self.store.enabledFirstPartyProvidersForDisplay())
        guard let provider = self.focusedAppProviderSelection.activatedApplication(
            bundleIdentifier: bundleIdentifier,
            isEnabled: self.settings.autoSelectProviderForFocusedApp,
            isMerged: self.shouldMergeIcons,
            enabledProviders: enabledProviders)
        else {
            return
        }
        guard self.selectedMenuProvider != provider.instanceID || self.settings.mergedMenuLastSelectedWasOverview else {
            return
        }

        self.preservingMergedSwitcherContentCachesDuringInvalidation {
            self.settings.mergedMenuLastSelectedWasOverview = false
            self.selectedMenuProvider = provider.instanceID
            self.lastMenuProvider = provider.instanceID
            self.lastMergedSwitcherSelection = .provider(provider.instanceID)
            self.refreshProviderSelectionDependentUI(deferRendering: true)
        }
    }
}
