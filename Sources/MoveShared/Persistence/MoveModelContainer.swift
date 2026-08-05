#if canImport(SwiftData)
import SwiftData

public enum MovePersistenceMode: Sendable { case cloudKit, localOnly }

public enum MoveModelContainer {
    public static let cloudKitIdentifier = "iCloud.cc.spel.move"
    public static func make(schema: Schema, mode: MovePersistenceMode = .cloudKit) throws -> ModelContainer {
        switch mode {
        case .cloudKit:
            let configuration = ModelConfiguration("Move", schema: schema, cloudKitDatabase: .private(cloudKitIdentifier))
            return try ModelContainer(for: schema, configurations: [configuration])
        case .localOnly:
            let configuration = ModelConfiguration("Move", schema: schema, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: [configuration])
        }
    }

    public static func makeWithFallback(schema: Schema) -> (container: ModelContainer, mode: MovePersistenceMode) {
        if let cloud = try? make(schema: schema, mode: .cloudKit) { return (cloud, .cloudKit) }
        do { return (try make(schema: schema, mode: .localOnly), .localOnly) }
        catch { fatalError("Move persistent store unavailable: \(error)") }
    }
}
#endif
