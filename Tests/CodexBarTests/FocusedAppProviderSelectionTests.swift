import CodexBarCore
import Testing
@testable import CodexBar

struct FocusedAppProviderSelectionTests {
    @Test(arguments: [
        ("com.openai.codex", UsageProvider.codex),
        ("com.anthropic.claudefordesktop", .claude),
        ("com.todesktop.230313mzl4w4u92", .cursor),
        ("com.exafunction.windsurf", .windsurf),
        ("dev.warp.Warp-Stable", .warp),
        ("dev.zed.Zed", .zed),
        ("com.google.GeminiMacOS", .gemini),
        ("com.google.antigravity", .antigravity),
        ("com.electron.ollama", .ollama),
        ("com.microsoft.VSCode", .copilot),
    ])
    func `resolves supported desktop app bundle identifiers`(
        bundleIdentifier: String,
        provider: UsageProvider)
    {
        #expect(FocusedAppProviderResolver.provider(for: bundleIdentifier) == provider)
    }

    @Test
    func `resolves JetBrains bundle identifier prefixes`() {
        #expect(FocusedAppProviderResolver.provider(for: "com.jetbrains.intellij") == .jetbrains)
        #expect(FocusedAppProviderResolver.provider(for: "jetbrains.rider") == .jetbrains)
    }

    @Test
    func `does not resolve unknown app bundle identifiers`() {
        #expect(FocusedAppProviderResolver.provider(for: "com.apple.Safari") == nil)
        #expect(FocusedAppProviderResolver.provider(for: nil) == nil)
    }

    @Test
    func `activation selects only an enabled matching provider`() {
        var coordinator = FocusedAppProviderSelectionCoordinator()
        #expect(coordinator.activatedApplication(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            isEnabled: true,
            isMerged: true,
            enabledProviders: [.claude]) == .claude)

        var disabledCoordinator = FocusedAppProviderSelectionCoordinator()
        #expect(disabledCoordinator.activatedApplication(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            isEnabled: true,
            isMerged: true,
            enabledProviders: [.codex]) == nil)
    }

    @Test
    func `manual selection wins until the focused app changes`() {
        var coordinator = FocusedAppProviderSelectionCoordinator()
        let enabled: Set<UsageProvider> = [.codex, .claude]
        #expect(coordinator.activatedApplication(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            isEnabled: true,
            isMerged: true,
            enabledProviders: enabled) == .claude)

        coordinator.recordManualSelection()
        #expect(coordinator.activatedApplication(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            isEnabled: true,
            isMerged: true,
            enabledProviders: enabled) == nil)
        #expect(coordinator.activatedApplication(
            bundleIdentifier: "com.openai.codex",
            isEnabled: true,
            isMerged: true,
            enabledProviders: enabled) == .codex)
    }

    @Test
    func `does not select while disabled or outside merged mode`() {
        var coordinator = FocusedAppProviderSelectionCoordinator()
        let enabled: Set<UsageProvider> = [.claude]
        #expect(coordinator.activatedApplication(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            isEnabled: false,
            isMerged: true,
            enabledProviders: enabled) == nil)
        #expect(coordinator.activatedApplication(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            isEnabled: true,
            isMerged: false,
            enabledProviders: enabled) == nil)
    }
}
