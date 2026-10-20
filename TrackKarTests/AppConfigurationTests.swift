import Foundation
import Testing

struct AppConfigurationTests {
    @Test func runsAsMenuBarAgent() {
        // Hosted tests run inside the app, so Bundle.main is TrackKar.app.
        let isAgent = Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? Bool
        #expect(isAgent == true)
    }

    @Test func usesExpectedBundleIdentifier() {
        #expect(Bundle.main.bundleIdentifier == "com.praveenkumar.TrackKar")
    }
}
