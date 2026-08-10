import CodexBarCore
import Foundation

/// Built-in associations between provider desktop clients and their usage provider.
enum FocusedAppProviderResolver {
    private static let providersByBundleIdentifier: [String: UsageProvider] = [
        "com.openai.codex": .codex,
        "com.openai.chat": .codex,
        "com.openai.chatgpt": .codex,
        "com.anthropic.claudefordesktop": .claude,
        "com.todesktop.230313mzl4w4u92": .cursor,
        "com.exafunction.windsurf": .windsurf,
        "dev.warp.Warp-Stable": .warp,
        "dev.zed.Zed": .zed,
        "com.google.GeminiMacOS": .gemini,
        "com.google.antigravity": .antigravity,
        "com.electron.ollama": .ollama,
        "com.microsoft.VSCode": .copilot,
        "com.microsoft.VSCodeInsiders": .copilot,
    ]

    static func provider(for bundleIdentifier: String?) -> UsageProvider? {
        guard let bundleIdentifier else { return nil }
        if bundleIdentifier.hasPrefix("com.jetbrains.") || bundleIdentifier.hasPrefix("jetbrains.") {
            return .jetbrains
        }
        return self.providersByBundleIdentifier[bundleIdentifier]
    }
}

/// Selection policy independent of AppKit notification delivery, enabling focused tests.
struct FocusedAppProviderSelectionCoordinator {
    private(set) var activeBundleIdentifier: String?
    private var manualOverrideBundleIdentifier: String?

    mutating func activatedApplication(
        bundleIdentifier: String?,
        isEnabled: Bool,
        isMerged: Bool,
        enabledProviders: Set<UsageProvider>) -> UsageProvider?
    {
        if bundleIdentifier != self.activeBundleIdentifier {
            self.activeBundleIdentifier = bundleIdentifier
            self.manualOverrideBundleIdentifier = nil
        }
        guard isEnabled, isMerged,
              self.manualOverrideBundleIdentifier != bundleIdentifier,
              let provider = FocusedAppProviderResolver.provider(for: bundleIdentifier),
              enabledProviders.contains(provider)
        else {
            return nil
        }
        return provider
    }

    mutating func recordManualSelection() {
        self.manualOverrideBundleIdentifier = self.activeBundleIdentifier
    }

    mutating func resetManualOverride() {
        self.manualOverrideBundleIdentifier = nil
    }

    mutating func reset() {
        self.activeBundleIdentifier = nil
        self.manualOverrideBundleIdentifier = nil
    }
}
