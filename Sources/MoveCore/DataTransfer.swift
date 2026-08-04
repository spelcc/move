import Foundation

public enum DataTransferError: Error, Equatable { case invalidJSON }

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
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
        guard let imported = try? decoder.decode([ActivityRecord].self, from: data) else { throw DataTransferError.invalidJSON }
        let existingIDs = Set(existing.map(\.id))
        return imported.filter { !existingIDs.contains($0.id) }
    }

    private static func csvEscape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
