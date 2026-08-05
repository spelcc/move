import Foundation
import MoveCore

enum MoveCopy {
    static func text(_ key: String) -> String {
        NSLocalizedString(key, bundle: .main, comment: "Move interface copy")
    }

    static func exerciseName(_ exercise: Exercise) -> String {
        let key = "exercise.name.\(exercise.id)"
        return NSLocalizedString(key, tableName: nil, bundle: .main, value: exercise.name, comment: "Built-in exercise name")
    }
}

extension Exercise {
    var displayName: String { MoveCopy.exerciseName(self) }
}

extension CustomExerciseEntity {
    var displayName: String { name }
}
