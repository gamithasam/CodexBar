import AppKit
import CodexBarCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct AppProviderMappingsView: View {
    @Bindable var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var invalidApp = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("auto_provider_configure")).font(.headline)
            Text(L("auto_provider_mapping_help")).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(self.settings.appProviderMappings) { mapping in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(mapping.displayName)
                                Text(mapping.bundleIdentifier).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Picker(L("auto_provider_provider"), selection: self.providerBinding(for: mapping)) {
                                ForEach(UsageProvider.allCases, id: \.self) { provider in
                                    Text(ProviderDescriptorRegistry.descriptor(for: provider).metadata.displayName)
                                        .tag(provider)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 180)
                            Button {
                                self.settings.appProviderMappings.removeAll { $0.id == mapping.id }
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .accessibilityLabel(L("auto_provider_remove"))
                        }
                    }
                }
            }
            HStack {
                Button(L("auto_provider_add")) { self.chooseApplication() }
                Button(L("auto_provider_restore")) {
                    self.settings.appProviderMappings = AppProviderMapping.defaults
                }
                Spacer()
                Button(L("auto_provider_done")) { self.dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 620, height: 440)
        .alert(L("auto_provider_invalid_app"), isPresented: self.$invalidApp) {
            Button(L("auto_provider_done"), role: .cancel) {}
        }
    }

    private func providerBinding(for mapping: AppProviderMapping) -> Binding<UsageProvider> {
        Binding(
            get: {
                self.settings.appProviderMappings.first(where: { $0.id == mapping.id })?.provider ?? mapping.provider
            },
            set: { provider in
                var mappings = self.settings.appProviderMappings
                guard let index = mappings.firstIndex(where: { $0.id == mapping.id }) else { return }
                mappings[index].provider = provider
                self.settings.appProviderMappings = mappings
            })
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier, !identifier.isEmpty else {
            self.invalidApp = true
            return
        }
        guard !self.settings.appProviderMappings.contains(where: { $0.id == identifier }) else { return }
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        // Provider-specific by design: Codex is the initial editable target for a newly added app.
        self.settings.appProviderMappings.append(AppProviderMapping(
            bundleIdentifier: identifier,
            displayName: name,
            provider: .codex))
    }
}
