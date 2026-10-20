import Foundation
import SwiftData

enum Persistence {
    static let schema = Schema([
        ActivityGroup.self,
        Activity.self,
        TimeEntry.self,
        Segment.self,
        Break.self,
    ])

    /// Tests host the app, so the app itself also uses an in-memory store under test to keep real data untouched.
    static func makeContainer(inMemory: Bool = isRunningTests) -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Could not open the Track Kar database: \(error)")
        }
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
