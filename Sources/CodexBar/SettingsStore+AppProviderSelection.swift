import Foundation

extension SettingsStore {
    var automaticProviderSelectionEnabled: Bool {
        get { self.defaultsState.automaticProviderSelectionEnabled }
        set {
            if newValue { self.menuBarShowsHighestUsage = false }
            self.defaultsState.automaticProviderSelectionEnabled = newValue
            self.userDefaults.set(newValue, forKey: "automaticProviderSelectionEnabled")
        }
    }

    var appProviderMappings: [AppProviderMapping] {
        get { self.defaultsState.appProviderMappings }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            self.defaultsState.appProviderMappings = newValue
            self.userDefaults.set(data, forKey: "appProviderMappings")
        }
    }

    static func loadAppProviderMappings(userDefaults: UserDefaults) -> [AppProviderMapping] {
        guard let data = userDefaults.data(forKey: "appProviderMappings"),
              let mappings = try? JSONDecoder().decode([AppProviderMapping].self, from: data)
        else { return AppProviderMapping.defaults }
        var identifiers: Set<String> = []
        return mappings.filter {
            !$0.bundleIdentifier.isEmpty && identifiers.insert($0.bundleIdentifier).inserted
        }
    }
}
