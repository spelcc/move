import Foundation

public enum DataTransferError: Error, Equatable { case invalidJSON, duplicateIDs }

public struct ImportSummary: Equatable, Sendable {
    public let total: Int
    public let newRecords: Int
    public let duplicateRecords: Int
    public init(total: Int, newRecords: Int, duplicateRecords: Int) {
        self.total = total; self.newRecords = newRecords; self.duplicateRecords = duplicateRecords
    }
}

public enum DataTransferService {
    public static func exportJSON(_ records: [ActivityRecord]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(records)
    }

    public static func exportCSV(_ records: [ActivityRecord]) -> String {
        var lines = ["id,exercise_id,performed_at,amount,metric,status,source,workout_id"]
        let formatter = ISO8601DateFormatter()
        lines += records.map { record in
            [record.id.uuidString, record.exerciseID, formatter.string(from: record.performedAt),
             String(record.amount), record.metric.rawValue, record.status.rawValue, record.source.rawValue,
             record.workoutID?.uuidString ?? ""].map(csvEscape).joined(separator: ",")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public static func importJSON(_ data: Data, existing: [ActivityRecord] = []) throws -> [ActivityRecord] {
        let imported = try decodeJSON(data)
        let existingIDs = Set(existing.map(\.id))
        var seen = existingIDs
        return imported.filter { seen.insert($0.id).inserted }
    }

    public static func previewImport(_ data: Data, existing: [ActivityRecord] = []) throws -> (records: [ActivityRecord], summary: ImportSummary) {
        let imported = try decodeJSON(data)
        let existingIDs = Set(existing.map(\.id))
        var seen = existingIDs
        let records = imported.filter { seen.insert($0.id).inserted }
        return (records, ImportSummary(total: imported.count, newRecords: records.count, duplicateRecords: imported.count - records.count))
    }

    private static func decodeJSON(_ data: Data) throws -> [ActivityRecord] {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
        guard let imported = try? decoder.decode([ActivityRecord].self, from: data) else { throw DataTransferError.invalidJSON }
        return imported
    }

    private static func csvEscape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
