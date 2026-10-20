import KeyboardShortcuts
import SwiftUI

/// Shown once on first launch: a menu-bar-only app is otherwise easy to lose.
struct WelcomeView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.appTheme) private var theme
    @AppStorage(PreferenceKey.hasSeenWelcome) private var hasSeenWelcome = false

    private var shortcut: String {
        KeyboardShortcuts.getShortcut(for: .togglePopover)?.description ?? "⌃⌥T"
    }

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                // Straight from the bundle: the system icon cache can lag behind new builds.
                Image(nsImage: Bundle.main.image(forResource: "AppIcon") ?? NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 88, height: 88)
                    .accessibilityHidden(true)
                Text("Welcome to Track Kar")
                    .font(.title.weight(.semibold))
                Text("A simple time tracker that lives in your menu bar.")
                    .foregroundStyle(theme.secondaryText)
            }

            VStack(alignment: .leading, spacing: 16) {
                row(
                    "menubar.arrow.up.rectangle",
                    title: "Find it in the menu bar",
                    detail: "Click the timer icon at the top of your screen, or press \(shortcut) from any app."
                )
                row(
                    "play.circle",
                    title: "Start with a name",
                    detail: "Type what you're working on and press Return. Save names as activities so their time adds up across days."
                )
                row(
                    "chart.bar.xaxis",
                    title: "See where your time went",
                    detail: "Open the full window for your dashboard, history, activities and settings."
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                Button("Open Settings") {
                    finish()
                    navigation.showSettings(using: openWindow)
                }
                .themedButton()
                Button("Get Started") {
                    finish()
                    StatusItemButton.toggle()
                }
                .themedButton(prominent: true)
                .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
        .padding(32)
        .frame(width: 460)
        .onAppear { AppActivation.bringToFront() }
        .onDisappear { hasSeenWelcome = true }
    }

    private func row(_ systemImage: String, title: LocalizedStringKey, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(theme.accent)
                .frame(width: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func finish() {
        hasSeenWelcome = true
        dismissWindow(id: WindowID.welcome)
    }
}
