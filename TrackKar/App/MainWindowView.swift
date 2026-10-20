import SwiftUI

/// Placeholder for the full app window. Replaced by the sidebar shell in Phase 2.
struct MainWindowView: View {
    var body: some View {
        ContentUnavailableView(
            "Track Kar",
            systemImage: "timer",
            description: Text("Dashboard, history and activities will live here.")
        )
        .frame(minWidth: 600, minHeight: 400)
    }
}

#Preview {
    MainWindowView()
}
