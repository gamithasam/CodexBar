import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

struct FocusedAppProviderSelectionTests {
    private let codex = "com.openai.codex"
    private let claude = "com.anthropic.claudefordesktop"
    private let ownApp = "com.steipete.codexbar"

    private func focus(
        _ app: String?,
        policy: inout FocusedAppProviderSelection,
        mappings: [AppProviderMapping] = AppProviderMapping.defaults,
        enabled: Set<UsageProvider> = [.codex, .claude],
        menuOpen: Bool = false) -> UsageProvider?
    {
        policy.focus(
            bundleIdentifier: app,
            ownBundleIdentifier: self.ownApp,
            mappings: mappings,
            enabledProviders: enabled,
            menuIsOpen: menuOpen)
    }

    @Test
    func `startup and repeated focus select enabled mapped providers only`() {
        var policy = FocusedAppProviderSelection()
        #expect(self.focus(self.codex, policy: &policy) == .codex)
        #expect(self.focus(self.codex, policy: &policy) == .codex)
        #expect(self.focus(nil, policy: &policy) == nil)
        #expect(self.focus("unrelated.app", policy: &policy) == nil)
        #expect(self.focus(self.ownApp, policy: &policy) == nil)
        #expect(self.focus(self.claude, policy: &policy, enabled: [.codex]) == nil)
    }

    @Test(arguments: [UsageProvider.codex, .claude, nil])
    func `manual selection including same provider and overview wins until another mapped app`(
        manualProvider: UsageProvider?)
    {
        var policy = FocusedAppProviderSelection()
        _ = self.focus(self.codex, policy: &policy)
        policy.recordManualSelection(provider: manualProvider)
        #expect(self.focus(self.codex, policy: &policy) == nil)
        #expect(self.focus(self.ownApp, policy: &policy) == nil)
        #expect(self.focus("unrelated.app", policy: &policy) == nil)
        #expect(self.focus(self.codex, policy: &policy) == nil)
        #expect(self.focus("com.todesktop.230313mzl4w4u92", policy: &policy) == nil)
        #expect(self.focus(self.codex, policy: &policy) == nil)
        #expect(self.focus(self.claude, policy: &policy) == .claude)
        #expect(self.focus(self.codex, policy: &policy) == .codex)
    }

    @Test
    func `another app mapped to the same provider clears manual override`() {
        var policy = FocusedAppProviderSelection()
        let mappings = AppProviderMapping.defaults + [
            AppProviderMapping(bundleIdentifier: "other.codex", displayName: "Other", provider: .codex),
        ]
        _ = self.focus(self.codex, policy: &policy)
        policy.recordManualSelection(provider: .claude)
        #expect(self.focus("other.codex", policy: &policy, mappings: mappings) == .codex)
    }

    @Test
    func `only the latest focus event is applied after menu close`() {
        var policy = FocusedAppProviderSelection()
        #expect(self.focus(self.codex, policy: &policy, menuOpen: true) == nil)
        #expect(self.focus(self.claude, policy: &policy, menuOpen: true) == nil)
        #expect(policy
            .menuClosed(mappings: AppProviderMapping.defaults, enabledProviders: [.codex, .claude]) == .claude)
        #expect(policy.menuClosed(mappings: AppProviderMapping.defaults, enabledProviders: [.codex, .claude]) == nil)
        _ = self.focus(self.codex, policy: &policy, menuOpen: true)
        _ = self.focus("unrelated.app", policy: &policy, menuOpen: true)
        #expect(policy.menuClosed(mappings: AppProviderMapping.defaults, enabledProviders: [.codex, .claude]) == nil)
        _ = self.focus(self.codex, policy: &policy, menuOpen: true)
        _ = self.focus(nil, policy: &policy, menuOpen: true)
        #expect(policy.menuClosed(mappings: AppProviderMapping.defaults, enabledProviders: [.codex, .claude]) == nil)
    }

    @Test
    func `manual selection cancels pending focus event`() {
        var policy = FocusedAppProviderSelection()
        _ = self.focus(self.claude, policy: &policy, menuOpen: true)
        policy.recordManualSelection(provider: .codex)
        #expect(policy.menuClosed(mappings: AppProviderMapping.defaults, enabledProviders: [.codex, .claude]) == nil)
        #expect(self.focus(self.claude, policy: &policy) == nil)
    }

    @Test
    func `disabling manually selected provider clears override`() {
        var policy = FocusedAppProviderSelection()
        _ = self.focus(self.codex, policy: &policy)
        policy.recordManualSelection(provider: .claude)
        policy.reconcile(enabledProviders: [.codex])
        #expect(self.focus(self.codex, policy: &policy, enabled: [.codex]) == .codex)
    }

    @Test
    func `custom mappings override defaults and removed mappings stay absent`() {
        var policy = FocusedAppProviderSelection()
        var mappings = AppProviderMapping.defaults
        mappings[0].provider = .minimax
        #expect(self.focus(self.codex, policy: &policy, mappings: mappings, enabled: [.minimax]) == .minimax)
        mappings.removeAll { $0.bundleIdentifier == self.codex }
        #expect(self.focus(self.codex, policy: &policy, mappings: mappings) == nil)
        #expect(self.focus(self.codex, policy: &policy) == .codex)
        #expect(AppProviderMapping.defaults.count == 18)
    }

    @Test
    func `defaults include verified native provider applications`() {
        let mappings = Dictionary(uniqueKeysWithValues: AppProviderMapping.defaults.map {
            ($0.bundleIdentifier, $0.provider)
        })

        #expect(mappings["com.openai.chat"] == .openai)
        #expect(mappings["com.google.GeminiMacOS"] == .gemini)
        #expect(mappings["com.google.antigravity-ide"] == .antigravity)
        #expect(mappings["dev.kiro.desktop"] == .kiro)
        #expect(mappings["ai.opencode.desktop"] == .opencode)
        #expect(mappings["com.exafunction.windsurf"] == .windsurf)
        #expect(mappings["com.qoder.qoder"] == .qoder)
        #expect(mappings["dev.zed.Zed"] == .zed)
        #expect(mappings["ai.perplexity.mac"] == .perplexity)
        #expect(mappings["ai.perplexity.comet"] == .perplexity)
        #expect(mappings["com.microsoft.VSCodeInsiders"] == .copilot)
    }
}
