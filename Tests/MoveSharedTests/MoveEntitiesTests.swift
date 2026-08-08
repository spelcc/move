import Testing
import MoveCore
@testable import MoveShared

@Test func customExerciseRoundTripsToDomainModel() {
    let entity = CustomExerciseEntity(
        name: "Rotation",
        category: .mobility,
        metric: .seconds,
        defaultAmount: 30,
        equipment: ["band"],
        tags: ["difficulty-2"],
        muscleZones: ["shoulders"]
    )
    #expect(entity.exercise?.name == "Rotation")
    #expect(entity.exercise?.difficulty == 2)
    #expect(entity.exercise?.equipment == ["band"])
}

@Test func reminderHostRoundTrips() {
    let settings = AppSettingsEntity(reminderHost: .mac)
    #expect(settings.reminderHost == .mac)
    settings.reminderHost = .all
    #expect(settings.reminderHost == .all)
}

@Test func activityAmountCanBeCorrected() {
    let entity = ActivityEntity(record: ActivityRecord(
        exerciseID: "squats",
        amount: 10,
        metric: .repetitions,
        status: .completed,
        source: .manual
    ))

    entity.update(amount: 24)

    #expect(entity.amount == 24)
    #expect(entity.record.amount == 24)
    #expect(entity.updatedAt >= entity.createdAt)
}
