import SwiftUI
import SwiftData
import MoveCore
import MoveShared

struct iOSActivityAmountEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let activity: ActivityEntity
    let exercise: Exercise?
    @State private var amount: Int

    init(activity: ActivityEntity, exercise: Exercise?) {
        self.activity = activity
        self.exercise = exercise
        _amount = State(initialValue: activity.amount)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Mouvement", value: exercise?.name ?? activity.exerciseID)
                    LabeledContent("Date") {
                        Text(activity.performedAt, format: .dateTime.day().month().year().hour().minute())
                    }
                }
                Section("Quantité") {
                    Stepper(value: $amount, in: 0...9999) {
                        HStack {
                            Text("Nombre")
                            Spacer()
                            Text(amountLabel)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                }
            }
        }
    }

    private var amountLabel: String {
        switch ExerciseMetric(rawValue: activity.metricRaw) {
        case .repetitions: "\(amount) répétitions"
        case .seconds: "\(amount) secondes"
        case .minutes: "\(amount) minutes"
        default: "\(amount)"
        }
    }

    private func save() {
        activity.update(amount: amount)
        try? modelContext.save()
        dismiss()
    }
}
