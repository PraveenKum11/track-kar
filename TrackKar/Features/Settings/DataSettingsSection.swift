import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Settings → General → Data: back up everything, or erase all tracked data.
struct DataSettingsSection: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.modelContext) private var context
    @Query private var entries: [TimeEntry]
    @Query private var activities: [Activity]
    @Query private var groups: [ActivityGroup]

    @State private var pendingExport: PreparedExport?
    @State private var isConfirmingErase = false
    @State private var errorMessage: String?

    var body: some View {
        Section {
            LabeledContent {
                Button("Back Up Everything…", action: backUp)
            } label: {
                Text("Backup")
                Text("Saves every session, activity and group as a JSON file.")
            }

            LabeledContent {
                Button("Erase All Data…", role: .destructive) { isConfirmingErase = true }
                    .disabled(entries.isEmpty && activities.isEmpty && groups.isEmpty)
            } label: {
                Text("Erase all data")
                Text(summary)
            }
        } header: {
            Text("Data")
        } footer: {
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
        .confirmationDialog(
            "Erase all Track Kar data?",
            isPresented: $isConfirmingErase,
            titleVisibility: .visible
        ) {
            Button("Back Up First…", action: backUp)
            Button("Erase Everything", role: .destructive, action: erase)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes \(summary.lowercased()), including any running timer. Your settings and shortcuts are kept. This can't be undone.")
        }
        .fileExporter(
            isPresented: Binding(get: { pendingExport != nil }, set: { if !$0 { pendingExport = nil } }),
            document: pendingExport?.document,
            contentType: .json,
            defaultFilename: pendingExport?.filename
        ) { result in
            if case .failure(let error) = result {
                errorMessage = error.localizedDescription
            }
        }
    }

    private var summary: String {
        String.inflected("^[\(entries.count) session](inflect: true), ^[\(activities.count) activity](inflect: true) and ^[\(groups.count) group](inflect: true)")
    }

    private func backUp() {
        do {
            pendingExport = try PreparedExport.make(.json, in: nil, context: context)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func erase() {
        engine.eraseAllData()
        if case .group = navigation.selection { navigation.selection = .settings }
        errorMessage = nil
    }
}
