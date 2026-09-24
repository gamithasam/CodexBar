import CodexBarCore

extension StatusItemController {
    func synchronizeFrontmostProviderMonitor() {
        let shouldMonitor = self.settings.unifiedIconSource == .frontmostApp
        guard shouldMonitor else {
            self.frontmostProviderMonitor?.stop()
            self.frontmostProviderMonitor = nil
            return
        }

        if self.frontmostProviderMonitor == nil {
            self.frontmostProviderMonitor = FrontmostProviderMonitor(
                source: WorkspaceFrontmostApplicationEventSource(),
                enabledProviders: { [weak self] in
                    guard let self else { return [] }
                    return Set(self.store.enabledFirstPartyProvidersForDisplay())
                },
                onChange: { [weak self] _ in
                    guard let self, !self.hasPreparedForAppShutdown else { return }
                    self.updateIcons()
                })
        }
        self.frontmostProviderMonitor?.start()
        self.frontmostProviderMonitor?.refresh()
    }
}
