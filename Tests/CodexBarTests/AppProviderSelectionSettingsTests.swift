import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

@MainActor
struct AppProviderSelectionSettingsTests {
    @Test
    func `fresh install starts with automatic selection disabled and default mappings`() throws {
        try self.withStores { defaults, makeStore in
            #expect(defaults.object(forKey: "automaticProviderSelectionEnabled") == nil)
            #expect(defaults.object(forKey: "appProviderMappings") == nil)

            let freshInstall = makeStore()

            #expect(!freshInstall.automaticProviderSelectionEnabled)
            #expect(freshInstall.appProviderMappings == AppProviderMapping.defaults)
            #expect(freshInstall.selectedMenuProvider == nil)
            #expect(!freshInstall.mergedMenuLastSelectedWasOverview)
        }
    }

    @Test
    func `upgrade preserves existing preferences while automatic selection stays opt in`() throws {
        try self.withStores { defaults, makeStore in
            defaults.set(ProviderInstanceID.copilot.rawValue, forKey: "selectedMenuProvider")
            defaults.set(true, forKey: "mergedMenuLastSelectedWasOverview")
            defaults.set(true, forKey: "menuBarShowsHighestUsage")

            #expect(defaults.object(forKey: "automaticProviderSelectionEnabled") == nil)
            #expect(defaults.object(forKey: "appProviderMappings") == nil)

            let upgraded = makeStore()

            #expect(!upgraded.automaticProviderSelectionEnabled)
            #expect(upgraded.selectedMenuProvider == .copilot)
            #expect(upgraded.mergedMenuLastSelectedWasOverview)
            #expect(upgraded.menuBarShowsHighestUsage)
            #expect(upgraded.appProviderMappings == AppProviderMapping.defaults)

            upgraded.automaticProviderSelectionEnabled = true

            #expect(upgraded.automaticProviderSelectionEnabled)
            #expect(!upgraded.menuBarShowsHighestUsage)
            #expect(upgraded.selectedMenuProvider == .copilot)
            #expect(upgraded.mergedMenuLastSelectedWasOverview)
        }
    }

    @Test
    func `automatic selection persists and is mutually exclusive with highest usage`() throws {
        try self.withStores { defaults, makeStore in
            let store = makeStore()
            #expect(!store.automaticProviderSelectionEnabled)
            #expect(store.appProviderMappings == AppProviderMapping.defaults)
            store.menuBarShowsHighestUsage = true
            store.automaticProviderSelectionEnabled = true
            #expect(!store.menuBarShowsHighestUsage)
            let reloaded = makeStore()
            #expect(reloaded.automaticProviderSelectionEnabled)
            #expect(!reloaded.menuBarShowsHighestUsage)
            reloaded.menuBarShowsHighestUsage = true
            #expect(!reloaded.automaticProviderSelectionEnabled)
            #expect(!defaults.bool(forKey: "automaticProviderSelectionEnabled"))
            defaults.set(true, forKey: "automaticProviderSelectionEnabled")
            defaults.set(true, forKey: "menuBarShowsHighestUsage")
            let conflicting = makeStore()
            #expect(conflicting.automaticProviderSelectionEnabled)
            #expect(!conflicting.menuBarShowsHighestUsage)
            #expect(!defaults.bool(forKey: "menuBarShowsHighestUsage"))
        }
    }

    @Test
    func `custom and deleted mappings persist until defaults are restored`() throws {
        try self.withStores { _, makeStore in
            let store = makeStore()
            store.appProviderMappings[0].provider = .minimax
            store.appProviderMappings.removeAll { $0.provider == .claude }
            let custom = makeStore()
            #expect(custom.appProviderMappings == store.appProviderMappings)
            #expect(custom.appProviderMappings[0].provider == .minimax)
            #expect(!custom.appProviderMappings.contains { $0.provider == .claude })
            custom.appProviderMappings = []
            #expect(makeStore().appProviderMappings.isEmpty)
            custom.appProviderMappings = AppProviderMapping.defaults
            #expect(makeStore().appProviderMappings == AppProviderMapping.defaults)
        }
    }

    @Test
    func `corrupt mappings fall back and invalid or duplicate identifiers are filtered`() throws {
        let defaults = InMemoryUserDefaults()
        defaults.set(Data("invalid".utf8), forKey: "appProviderMappings")
        #expect(SettingsStore.loadAppProviderMappings(userDefaults: defaults) == AppProviderMapping.defaults)
        let mappings = [
            AppProviderMapping(bundleIdentifier: "", displayName: "Invalid", provider: .codex),
            AppProviderMapping(bundleIdentifier: "test.app", displayName: "First", provider: .minimax),
            AppProviderMapping(bundleIdentifier: "test.app", displayName: "Duplicate", provider: .claude),
        ]
        try defaults.set(JSONEncoder().encode(mappings), forKey: "appProviderMappings")
        #expect(SettingsStore.loadAppProviderMappings(userDefaults: defaults) == [mappings[1]])
    }

    private func withStores(
        operation: (InMemoryUserDefaults, () -> SettingsStore) throws -> Void) throws
    {
        try #require(SettingsStore.isRunningTests)
        let defaults = InMemoryUserDefaults()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var stores: [SettingsStore] = []
        defer { for store in stores {
            store.configFileWatcher?.stop()
        } }
        let makeStore = {
            let store = SettingsStore(
                userDefaults: defaults,
                configStore: CodexBarConfigStore(fileURL: root.appendingPathComponent("config.json")),
                zaiTokenStore: NoopZaiTokenStore(),
                syntheticTokenStore: NoopSyntheticTokenStore(),
                codexCookieStore: InMemoryCookieHeaderStore(),
                claudeCookieStore: InMemoryCookieHeaderStore(),
                cursorCookieStore: InMemoryCookieHeaderStore(),
                opencodeCookieStore: InMemoryCookieHeaderStore(),
                factoryCookieStore: InMemoryCookieHeaderStore(),
                minimaxCookieStore: InMemoryMiniMaxCookieStore(),
                minimaxAPITokenStore: InMemoryMiniMaxAPITokenStore(),
                kimiTokenStore: InMemoryKimiTokenStore(),
                augmentCookieStore: InMemoryCookieHeaderStore(),
                ampCookieStore: InMemoryCookieHeaderStore(),
                copilotTokenStore: InMemoryCopilotTokenStore(),
                tokenAccountStore: InMemoryTokenAccountStore(fileURL: root.appendingPathComponent("accounts.json")),
                antigravityOAuthCredentialsStore: AntigravityOAuthCredentialsStore(
                    fileURL: root.appendingPathComponent("antigravity.json")),
                keychainAccessPolicy: SettingsStoreKeychainAccessPolicy(
                    setDisabled: { _ in }, isExplicitlyDisabled: { true }),
                performInitialProviderDetection: false)
            stores.append(store)
            return store
        }
        try operation(defaults, makeStore)
    }
}
