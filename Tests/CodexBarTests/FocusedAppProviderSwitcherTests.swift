import AppKit
import CodexBarCore
import Testing
@testable import CodexBar

@MainActor
@Suite(.serialized)
struct FocusedAppProviderSwitcherTests {
    @Test(arguments: [false, true])
    func `clicking or using a shortcut on selected provider records manual intent`(keyboard: Bool) {
        _ = NSApplication.shared
        var selections: [ProviderSwitcherSelection] = []
        let view = ProviderSwitcherView(
            providers: [.codex, .claude],
            selected: .provider(.codex),
            includesOverview: true,
            width: 320,
            showsIcons: false,
            iconProvider: { _ in NSImage() },
            weeklyRemainingProvider: { _ in nil },
            onSelect: { selections.append($0) })
        if keyboard {
            #expect(view.handleKeyboardSelection(at: 1))
        } else {
            #expect(view._test_simulateRuntimeClick(buttonTag: 1))
        }
        #expect(selections == [.provider(.codex)])
    }

    @Test
    func `selecting overview again records manual intent`() {
        _ = NSApplication.shared
        var selections: [ProviderSwitcherSelection] = []
        let view = ProviderSwitcherView(
            providers: [.codex, .claude],
            selected: .overview,
            includesOverview: true,
            width: 320,
            showsIcons: false,
            iconProvider: { _ in NSImage() },
            weeklyRemainingProvider: { _ in nil },
            onSelect: { selections.append($0) })
        #expect(view.handleKeyboardSelection(at: 0))
        #expect(selections == [.overview])
    }
}
