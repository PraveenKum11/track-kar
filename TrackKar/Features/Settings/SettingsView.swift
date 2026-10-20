import SwiftUI

/// The standard macOS Settings window (⌘,).
struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettingsView()
            }
            Tab("Timers", systemImage: "timer") {
                TimerSettingsView()
            }
            Tab("Menu Bar", systemImage: "menubar.rectangle") {
                MenuBarSettingsView()
            }
            Tab("Appearance", systemImage: "paintpalette") {
                AppearanceSettingsView()
            }
        }
        .frame(width: 520)
        .themedRoot()
    }
}

private struct GeneralSettingsView: View {
    @AppStorage(PreferenceKey.newActivityBehavior) private var newActivityBehavior: NewActivityBehavior = .ask
    @AppStorage(PreferenceKey.firstWeekday) private var firstWeekday: FirstWeekday = .system

    var body: some View {
        Form {
            Section {
                LaunchAtLoginToggle()
            }
            Section {
                Picker("When you start a new name", selection: $newActivityBehavior) {
                    ForEach(NewActivityBehavior.allCases) { behavior in
                        Text(behavior.label).tag(behavior)
                    }
                }
                .pickerStyle(.radioGroup)
            }
            Section {
                Picker("First day of week", selection: $firstWeekday) {
                    ForEach(FirstWeekday.allCases) { day in
                        Text(day.label).tag(day)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct AppearanceSettingsView: View {
    @AppStorage(PreferenceKey.appearanceMode) private var mode: AppearanceMode = .system
    @AppStorage(PreferenceKey.themeStyle) private var style: ThemeStyle = .glass
    @AppStorage(PreferenceKey.accentColor) private var accent: AccentChoice = .system
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Form {
            Section {
                PopoverPreview()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }

            Section {
                Picker("Mode", selection: $mode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Style", selection: $style) {
                    ForEach(ThemeStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                .pickerStyle(.radioGroup)
                .disabled(reduceTransparency)

                LabeledContent("Accent color") {
                    AccentPicker(selection: $accent)
                }
            } footer: {
                if reduceTransparency {
                    Text("Reduce Transparency is on in System Settings, so Track Kar uses the Solid style.")
                }
            }
        }
        .formStyle(.grouped)
        .frame(height: 520)
    }
}

private struct AccentPicker: View {
    @Binding var selection: AccentChoice

    var body: some View {
        HStack(spacing: 6) {
            ForEach(AccentChoice.allCases) { choice in
                Button {
                    selection = choice
                } label: {
                    Circle()
                        .fill(choice.color ?? Color.accentColor)
                        .overlay {
                            if choice == .system {
                                Circle().strokeBorder(.secondary, lineWidth: 1)
                            }
                        }
                        .frame(width: 18, height: 18)
                        .padding(2)
                        .overlay {
                            if choice == selection {
                                Circle().strokeBorder(.primary, lineWidth: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
                .help(choice.label)
                .accessibilityLabel(choice.label)
            }
        }
    }
}

/// A static mock of the popover in the current theme. It never touches real timer state.
private struct PopoverPreview: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Switch to something else…")
                .foregroundStyle(theme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .themedSurface(cornerRadius: 8)

            VStack(spacing: 8) {
                Text("1:24:05")
                    .font(.system(size: 34, weight: .light, design: .rounded))
                    .monospacedDigit()
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.activity(ActivityPalette.slots[0].light))
                        .frame(width: 8, height: 8)
                    Text("Interview prep")
                    Text("· 2 breaks")
                        .foregroundStyle(theme.secondaryText)
                }
                .font(.callout)
                HStack(spacing: 10) {
                    Button {} label: {
                        Label("Pause", systemImage: "pause.fill").frame(maxWidth: .infinity)
                    }
                    .themedButton()
                    Button {} label: {
                        Label("Stop", systemImage: "stop.fill").frame(maxWidth: .infinity)
                    }
                    .themedButton(prominent: true)
                }
            }
            .frame(maxWidth: .infinity)

            Divider()
            Text("Today 3h 42m")
                .font(.callout)
                .foregroundStyle(theme.secondaryText)
        }
        .padding(16)
        .frame(width: 300)
        .background(theme.style == .solid ? theme.surface : .clear)
        .glassBackgroundIfNeeded(theme.style)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview of the menu bar popover")
    }
}

private extension View {
    @ViewBuilder
    func glassBackgroundIfNeeded(_ style: ThemeStyle) -> some View {
        switch style {
        case .glass: glassEffect(.regular, in: .rect(cornerRadius: 16))
        case .solid: clipShape(.rect(cornerRadius: 16))
        }
    }
}
