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
        open(ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none))
    }

    static func makeContainer(url: URL) -> ModelContainer {
        open(ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
    }

    private static func open(_ configuration: ModelConfiguration) -> ModelContainer {
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
