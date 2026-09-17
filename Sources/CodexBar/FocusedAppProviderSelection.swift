import CodexBarCore
import Foundation

struct AppProviderMapping: Codable, Equatable, Identifiable, Sendable {
    var bundleIdentifier: String
    var displayName: String
    var provider: UsageProvider

    var id: String {
        self.bundleIdentifier
    }

    /// Provider-specific by design: dedicated native app bundle IDs map to matching usage providers.
    static let defaults: [Self] = [
        Self(bundleIdentifier: "com.openai.codex", displayName: "Codex", provider: .codex),
        Self(bundleIdentifier: "com.anthropic.claudefordesktop", displayName: "Claude", provider: .claude),
        Self(bundleIdentifier: "com.todesktop.230313mzl4w4u92", displayName: "Cursor", provider: .cursor),
        Self(bundleIdentifier: "com.google.antigravity", displayName: "Antigravity", provider: .antigravity),
        Self(bundleIdentifier: "com.microsoft.VSCode", displayName: "Visual Studio Code", provider: .copilot),
        Self(bundleIdentifier: "com.electron.ollama", displayName: "Ollama", provider: .ollama),
        Self(bundleIdentifier: "dev.warp.Warp-Stable", displayName: "Warp", provider: .warp),
    ]
}

/// Session-local manual intent and deferred focus events, independent of AppKit menu tracking.
struct FocusedAppProviderSelection {
    private(set) var focusedBundleIdentifier: String?
    private var manualOverride = false
    private var manualBundleIdentifier: String?
    private var manualProvider: UsageProvider?
    private var pendingBundleIdentifier: String?

    mutating func recordManualSelection(provider: UsageProvider?) {
        self.manualOverride = true
        self.manualBundleIdentifier = self.focusedBundleIdentifier
        self.manualProvider = provider
        self.pendingBundleIdentifier = nil
    }

    mutating func reconcile(enabledProviders: Set<UsageProvider>) {
        if let provider = self.manualProvider, !enabledProviders.contains(provider) {
            self.manualOverride = false
            self.manualProvider = nil
        }
    }

    mutating func focus(
        bundleIdentifier: String?,
        ownBundleIdentifier: String?,
        mappings: [AppProviderMapping],
        enabledProviders: Set<UsageProvider>,
        menuIsOpen: Bool) -> UsageProvider?
    {
        guard let bundleIdentifier else {
            self.focusedBundleIdentifier = nil
            self.pendingBundleIdentifier = nil
            return nil
        }
        guard bundleIdentifier != ownBundleIdentifier else { return nil }
        self.focusedBundleIdentifier = bundleIdentifier
        if menuIsOpen {
            self.pendingBundleIdentifier = bundleIdentifier
            return nil
        }
        self.pendingBundleIdentifier = nil
        self.reconcile(enabledProviders: enabledProviders)
        guard let provider = mappings.first(where: { $0.bundleIdentifier == bundleIdentifier })?.provider,
              enabledProviders.contains(provider)
        else { return nil }
        if self.manualOverride {
            guard bundleIdentifier != self.manualBundleIdentifier else { return nil }
            self.manualOverride = false
            self.manualProvider = nil
        }
        return provider
    }

    mutating func menuClosed(
        mappings: [AppProviderMapping],
        enabledProviders: Set<UsageProvider>) -> UsageProvider?
    {
        guard let pending = self.pendingBundleIdentifier else { return nil }
        return self.focus(
            bundleIdentifier: pending,
            ownBundleIdentifier: nil,
            mappings: mappings,
            enabledProviders: enabledProviders,
            menuIsOpen: false)
    }
}
