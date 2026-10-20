import SwiftUI

/// The standard macOS Settings window (⌘,). Phase 2 adds Menu Bar options, accent color and more.
struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettingsView()
            }
            Tab("Appearance", systemImage: "paintpalette") {
                AppearanceSettingsView()
            }
        }
        .frame(width: 480)
        .themedRoot()
    }
}

private struct GeneralSettingsView: View {
    @AppStorage(PreferenceKey.newActivityBehavior) private var newActivityBehavior: NewActivityBehavior = .ask

    var body: some View {
        Form {
            Picker("When you start a new name", selection: $newActivityBehavior) {
                ForEach(NewActivityBehavior.allCases) { behavior in
                    Text(behavior.label).tag(behavior)
                }
            }
            .pickerStyle(.radioGroup)
        }
        .formStyle(.grouped)
    }
}

private struct AppearanceSettingsView: View {
    @AppStorage(PreferenceKey.appearanceMode) private var mode: AppearanceMode = .system
    @AppStorage(PreferenceKey.themeStyle) private var style: ThemeStyle = .glass
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Form {
            Picker("Mode", selection: $mode) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Section {
                Picker("Style", selection: $style) {
                    ForEach(ThemeStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                .pickerStyle(.radioGroup)
                .disabled(reduceTransparency)
            } footer: {
                if reduceTransparency {
                    Text("Reduce Transparency is on in System Settings, so Track Kar uses the Solid style.")
                }
            }
        }
        .formStyle(.grouped)
    }
}
