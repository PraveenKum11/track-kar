import ServiceManagement
import SwiftUI

/// Registers the app as a login item through `SMAppService`, which works inside the sandbox.
struct LaunchAtLoginToggle: View {
    @State private var isEnabled = SMAppService.mainApp.status == .enabled
    @State private var errorMessage: String?

    var body: some View {
        // A closure literal rather than `set: setEnabled`: Swift 6.3 crashes generating the
        // thunk for that method reference (seen on CI's Xcode 26.6).
        Toggle(isOn: Binding(get: { isEnabled }, set: { setEnabled($0) })) {
            Text("Launch at login")
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
    }

    private func setEnabled(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
