import Foundation

public enum ExerciseLibrary {
    public static let builtIn: [Exercise] = [
        .init(id: "pushups", name: "Pompes", category: .strength, metric: .repetitions, defaultAmount: 10, difficulty: 2, tags: ["floor", "wrists"], emoji: "💪"),
        .init(id: "incline-pushups", name: "Pompes inclinées", category: .strength, metric: .repetitions, defaultAmount: 12, tags: ["wrists"], emoji: "📐"),
        .init(id: "knee-pushups", name: "Pompes sur les genoux", category: .strength, metric: .repetitions, defaultAmount: 10, tags: ["floor", "wrists"], emoji: "🦾"),
        .init(id: "squats", name: "Squats", category: .strength, metric: .repetitions, defaultAmount: 15, emoji: "🍑"),
        .init(id: "jump-squats", name: "Squats sautés", category: .cardio, metric: .repetitions, defaultAmount: 10, difficulty: 3, tags: ["jump", "noisy"], emoji: "🚀"),
        .init(id: "lunges", name: "Fentes", category: .strength, metric: .repetitions, defaultAmount: 12, emoji: "🦵"),
        .init(id: "reverse-lunges", name: "Fentes arrière", category: .strength, metric: .repetitions, defaultAmount: 12, emoji: "↩️"),
        .init(id: "pullups", name: "Tractions", category: .strength, metric: .repetitions, defaultAmount: 5, difficulty: 3, equipment: ["pullup-bar"], emoji: "🧗"),
        .init(id: "dead-hang", name: "Suspension", category: .strength, metric: .seconds, defaultAmount: 30, difficulty: 2, equipment: ["pullup-bar"], emoji: "🦥"),
        .init(id: "plank", name: "Gainage", category: .strength, metric: .seconds, defaultAmount: 60, tags: ["floor", "wrists"], emoji: "🪵"),
        .init(id: "side-plank", name: "Gainage latéral", category: .strength, metric: .seconds, defaultAmount: 30, difficulty: 2, tags: ["floor"], emoji: "📏"),
        .init(id: "mountain-climbers", name: "Mountain climbers", category: .cardio, metric: .seconds, defaultAmount: 30, difficulty: 2, tags: ["floor", "wrists"], emoji: "⛰️"),
        .init(id: "jumping-jacks", name: "Jumping jacks", category: .cardio, metric: .seconds, defaultAmount: 30, tags: ["jump", "noisy"], emoji: "⭐"),
        .init(id: "high-knees", name: "Montées de genoux", category: .cardio, metric: .seconds, defaultAmount: 30, tags: ["noisy"], emoji: "🏃"),
        .init(id: "glute-bridge", name: "Pont fessier", category: .strength, metric: .repetitions, defaultAmount: 15, tags: ["floor"], emoji: "🌉"),
        .init(id: "bird-dog", name: "Bird dog", category: .mobility, metric: .repetitions, defaultAmount: 12, tags: ["floor"], emoji: "🐕"),
        .init(id: "dead-bug", name: "Dead bug", category: .strength, metric: .repetitions, defaultAmount: 12, tags: ["floor"], emoji: "🪲"),
        .init(id: "calf-raises", name: "Mollets", category: .strength, metric: .repetitions, defaultAmount: 20, emoji: "🦶"),
        .init(id: "chair-dips", name: "Dips sur chaise", category: .strength, metric: .repetitions, defaultAmount: 10, difficulty: 2, equipment: ["chair"], tags: ["wrists"], emoji: "🪑"),
        .init(id: "shoulder-rolls", name: "Rotations d’épaules", category: .mobility, metric: .seconds, defaultAmount: 45, emoji: "🔄"),
        .init(id: "neck-mobility", name: "Mobilité cervicale", category: .mobility, metric: .seconds, defaultAmount: 45, emoji: "🦒"),
        .init(id: "hip-circles", name: "Rotations de hanches", category: .mobility, metric: .seconds, defaultAmount: 45, emoji: "⭕"),
        .init(id: "cat-cow", name: "Chat-vache", category: .mobility, metric: .seconds, defaultAmount: 60, tags: ["floor"], emoji: "🐈"),
        .init(id: "forward-fold", name: "Flexion avant", category: .stretch, metric: .seconds, defaultAmount: 45, emoji: "🙇"),
        .init(id: "chest-stretch", name: "Étirement pectoraux", category: .stretch, metric: .seconds, defaultAmount: 45, emoji: "🫶"),
        .init(id: "walk", name: "Marche", category: .recovery, metric: .minutes, defaultAmount: 5, emoji: "🚶"),
        .init(id: "stairs", name: "Escaliers", category: .cardio, metric: .minutes, defaultAmount: 3, emoji: "🪜"),
        .init(id: "dance", name: "Danse libre", category: .free, metric: .minutes, defaultAmount: 2, emoji: "🕺"),
        .init(id: "free-movement", name: "Mouvement libre", category: .free, metric: .minutes, defaultAmount: 2, emoji: "🌀"),
        .init(id: "eye-break", name: "Regarder au loin", category: .recovery, metric: .seconds, defaultAmount: 60, emoji: "👀")
    ]

    public static let quickWorkouts: [WorkoutTemplate] = [
        .init(name: "Réveil 5 min", rounds: 1, steps: ["shoulder-rolls", "squats", "incline-pushups", "bird-dog", "forward-fold"].map { .init(exerciseID: $0, workSeconds: 40, restSeconds: 20) }),
        .init(name: "Corps complet 10 min", rounds: 2, steps: ["squats", "pushups", "lunges", "plank", "jumping-jacks"].map { .init(exerciseID: $0, workSeconds: 40, restSeconds: 20) }),
        .init(name: "Silencieuse 10 min", rounds: 2, steps: ["reverse-lunges", "incline-pushups", "glute-bridge", "dead-bug", "chest-stretch"].map { .init(exerciseID: $0, workSeconds: 40, restSeconds: 20) })
        , .init(name: "Pause bureau 5 min", rounds: 1, steps: ["shoulder-rolls", "squats", "forward-fold"].map { .init(exerciseID: $0, workSeconds: 40, restSeconds: 20) })
        , .init(name: "Mobilité 5 min", rounds: 1, steps: ["neck-mobility", "shoulder-rolls", "hip-circles", "cat-cow"].map { .init(exerciseID: $0, workSeconds: 35, restSeconds: 10) })
        , .init(name: "Haut du corps 10 min", rounds: 2, steps: ["pushups", "pullups", "plank", "chair-dips"].map { .init(exerciseID: $0, workSeconds: 40, restSeconds: 20) })
        , .init(name: "Jambes 10 min", rounds: 2, steps: ["squats", "lunges", "reverse-lunges", "calf-raises"].map { .init(exerciseID: $0, workSeconds: 40, restSeconds: 20) })
        , .init(name: "Gainage 10 min", rounds: 2, steps: ["plank", "side-plank", "dead-bug", "bird-dog"].map { .init(exerciseID: $0, workSeconds: 40, restSeconds: 20) })
        , .init(name: "Sans matériel 10 min", rounds: 2, steps: ["squats", "incline-pushups", "reverse-lunges", "glute-bridge", "forward-fold"].map { .init(exerciseID: $0, workSeconds: 40, restSeconds: 20) })
        , .init(name: "Barre de traction 10 min", rounds: 3, steps: ["pullups", "dead-hang", "squats"].map { .init(exerciseID: $0, workSeconds: 30, restSeconds: 30) })
        , .init(name: "Étirements 10 min", rounds: 1, steps: ["forward-fold", "chest-stretch", "neck-mobility", "hip-circles"].map { .init(exerciseID: $0, workSeconds: 90, restSeconds: 15) })
        , .init(name: "Mouvement libre 10 min", rounds: 1, steps: [.init(exerciseID: "free-movement", workSeconds: 600, restSeconds: 0)])
        , .init(name: "Corps complet 15 min", rounds: 3, steps: ["squats", "pushups", "lunges", "plank", "shoulder-rolls"].map { .init(exerciseID: $0, workSeconds: 45, restSeconds: 15) })
    ]
}
