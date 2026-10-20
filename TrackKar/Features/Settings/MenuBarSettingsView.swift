import SwiftUI

/// Settings → Menu Bar: what the status item shows, with a live preview.
struct MenuBarSettingsView: View {
    @AppStorage(PreferenceKey.menuBarOptions) private var options = MenuBarOptions()
    @State private var previewState: TrackingState = .running

    var body: some View {
        Form {
            Section {
                preview
                Picker("Preview", selection: $previewState) {
                    Text("Running").tag(TrackingState.running)
                    Text("Paused").tag(TrackingState.paused)
                    Text("Idle").tag(TrackingState.idle)
                }
                .pickerStyle(.segmented)
            }

            Section("While tracking") {
                Toggle("Icon", isOn: $options.showIcon)
                Toggle("Elapsed time", isOn: $options.showTime)
                Toggle("Activity name", isOn: $options.showName)
                if options.showName {
                    Stepper("Shorten names to \(options.nameLength) characters", value: $options.nameLength, in: 4...40)
                }
                Toggle(isOn: $options.showColorDot) {
                    Text("Activity color dot")
                    Text("Shown in place of the icon.")
                }
                Picker("Time format", selection: $options.timeFormat) {
                    ForEach(MenuBarTimeFormat.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Fixed-width digits", isOn: $options.fixedWidth)
            }

            Section("While paused") {
                Picker("Paused style", selection: $options.pausedStyle) {
                    ForEach(MenuBarPausedStyle.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }

            Section {
                Picker("When not tracking", selection: $options.idleDisplay) {
                    ForEach(MenuBarIdleDisplay.allCases) { Text($0.label).tag($0) }
                }
            } footer: {
                if options.idleDisplay == .hidden {
                    Text("The menu bar item appears only while a timer runs. To start one, open Track Kar from Spotlight or the Applications folder.")
                }
            }

            Section("Icon") {
                Picker("Icon", selection: $options.icon) {
                    ForEach(MenuBarIcon.allCases) { icon in
                        Image(systemName: icon.symbolName).tag(icon)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Section {
                Button("Restore Defaults") { options = MenuBarOptions() }
                    .disabled(options == MenuBarOptions())
            }
        }
        .formStyle(.grouped)
        .frame(height: 640)
    }

    private var preview: some View {
        let content = MenuBarContent.make(
            options: options,
            state: previewState,
            elapsed: 5_045,
            activityName: "Interview prep",
            colorHex: ActivityPalette.slots[0].light,
            todayTotal: 13_379,
            blinkOn: true
        )
        return HStack(spacing: 14) {
            Spacer()
            Image(systemName: "wifi")
            Image(systemName: "battery.75percent")
            MenuBarLabelContent(content: content, fixedWidth: options.fixedWidth)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.white.opacity(0.15), in: .rect(cornerRadius: 4))
            Text(Date.now.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
        }
        .font(.system(size: 13))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(.black.opacity(0.75), in: .rect(cornerRadius: 6))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Menu bar preview")
    }
}
