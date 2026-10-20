import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum ExportFormat {
    case csv, json

    var contentType: UTType {
        switch self {
        case .csv: .commaSeparatedText
        case .json: .json
        }
    }
}

/// Turns entries into CSV (for spreadsheets) or JSON (a complete, re-importable record).
enum Exporter {
    static let csvHeader = [
        "Date", "Start", "End", "Duration", "Hours", "Activity", "Group", "Name",
        "Mode", "Breaks", "Break Minutes", "Pomodoros", "Notes",
    ]

    static func csv(_ entries: [TimeEntry], at now: Date) -> String {
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "yyyy-MM-dd"
        let timestamp = ISO8601DateFormatter()
        timestamp.timeZone = .current

        var lines = [csvHeader.map(escape).joined(separator: ",")]
        for entry in entries.sorted(by: { $0.createdAt < $1.createdAt }) {
            let seconds = entry.duration(at: now)
            let breakSeconds = (entry.breaks ?? []).reduce(0) { $0 + $1.duration(at: now) }
            let row = [
                day.string(from: entry.createdAt),
                timestamp.string(from: entry.createdAt),
                entry.endedAt.map(timestamp.string(from:)) ?? "",
                DurationFormat.clock(seconds),
                String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), seconds / 3_600),
                entry.activity?.name ?? "",
                entry.activity?.group?.name ?? "",
                entry.title,
                entry.mode.rawValue,
                String(entry.breakCount),
                String(Int((breakSeconds / 60).rounded())),
                entry.mode == .pomodoro ? String(entry.completedFocusCount) : "",
                entry.notes ?? "",
            ]
            lines.append(row.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// RFC 4180 quoting, and a leading apostrophe for cells a spreadsheet would run as a formula.
    static func escape(_ field: String) -> String {
        var field = field
        if let first = field.first, "=+-@".contains(first) {
            field = "'" + field
        }
        guard field.contains(where: { ",\"\r\n".contains($0) }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func json(
        _ entries: [TimeEntry],
        activities: [Activity],
        groups: [ActivityGroup],
        at now: Date
    ) throws -> Data {
        let file = ExportFile(
            version: 1,
            exportedAt: now,
            groups: groups.map {
                .init(id: $0.id, name: $0.name, colorHex: $0.colorHex, targetHours: $0.targetHours, isArchived: $0.isArchived)
            },
            activities: activities.map {
                .init(id: $0.id, name: $0.name, colorHex: $0.colorHex, groupID: $0.group?.id, isArchived: $0.isArchived)
            },
            entries: entries.sorted { $0.createdAt < $1.createdAt }.map { entry in
                .init(
                    id: entry.id,
                    title: entry.title,
                    activityID: entry.activity?.id,
                    mode: entry.mode.rawValue,
                    start: entry.createdAt,
                    end: entry.endedAt,
                    durationSeconds: entry.duration(at: now).rounded(),
                    targetDuration: entry.targetDuration,
                    completedPomodoros: entry.mode == .pomodoro ? entry.completedFocusCount : nil,
                    notes: entry.notes,
                    segments: (entry.segments ?? []).sorted { $0.start < $1.start }.map { .init(start: $0.start, end: $0.end) },
                    breaks: (entry.breaks ?? []).sorted { $0.start < $1.start }.map { .init(kind: $0.kind.rawValue, start: $0.start, end: $0.end) }
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(file)
    }
}

/// The JSON export layout. `version` lets a future importer read older files.
struct ExportFile: Codable, Equatable {
    struct Group: Codable, Equatable {
        var id: UUID
        var name: String
        var colorHex: String
        var targetHours: Double?
        var isArchived: Bool
    }

    struct Activity: Codable, Equatable {
        var id: UUID
        var name: String
        var colorHex: String
        var groupID: UUID?
        var isArchived: Bool
    }

    struct Entry: Codable, Equatable {
        struct Span: Codable, Equatable {
            var start: Date
            var end: Date?
        }

        struct Pause: Codable, Equatable {
            var kind: String
            var start: Date
            var end: Date?
        }

        var id: UUID
        var title: String
        var activityID: UUID?
        var mode: String
        var start: Date
        var end: Date?
        var durationSeconds: Double
        var targetDuration: Double?
        var completedPomodoros: Int?
        var notes: String?
        var segments: [Span]
        var breaks: [Pause]
    }

    var version: Int
    var exportedAt: Date
    var groups: [Group]
    var activities: [Activity]
    var entries: [Entry]
}

/// A ready-to-save export: what `fileExporter` needs.
struct PreparedExport {
    var document: ExportDocument
    var format: ExportFormat
    var filename: String

    /// Builds an export of entries overlapping `interval`, or everything when it's nil.
    static func make(_ format: ExportFormat, in interval: DateInterval?, context: ModelContext, now: Date = .now) throws -> PreparedExport {
        var descriptor = FetchDescriptor<TimeEntry>(sortBy: [SortDescriptor(\.createdAt)])
        if let interval {
            let start = interval.start
            let end = interval.end
            let openEnded = Date.distantFuture
            descriptor.predicate = #Predicate { $0.createdAt < end && ($0.endedAt ?? openEnded) > start }
        }
        let entries = try context.fetch(descriptor)
        let data: Data
        switch format {
        case .csv:
            data = Data(Exporter.csv(entries, at: now).utf8)
        case .json:
            data = try Exporter.json(
                entries,
                activities: try context.fetch(FetchDescriptor<Activity>(sortBy: [SortDescriptor(\.name)])),
                groups: try context.fetch(FetchDescriptor<ActivityGroup>(sortBy: [SortDescriptor(\.name)])),
                at: now
            )
        }
        let day = DateFormatter()
        day.dateFormat = "yyyy-MM-dd"
        let suffix = interval.map { "\(day.string(from: $0.start)) to \(day.string(from: $0.end.addingTimeInterval(-1)))" }
            ?? "All \(day.string(from: now))"
        return PreparedExport(document: ExportDocument(data: data), format: format, filename: "Track Kar \(suffix)")
    }
}

/// Wraps export bytes for `fileExporter`.
struct ExportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.commaSeparatedText, .json]

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
