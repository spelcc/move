import OSLog

enum MoveLogger {
    static let scheduler = Logger(subsystem: "cc.spel.move", category: "scheduler")
    static let persistence = Logger(subsystem: "cc.spel.move", category: "persistence")
    static let notifications = Logger(subsystem: "cc.spel.move", category: "notifications")
    static let workout = Logger(subsystem: "cc.spel.move", category: "workout")
}
