import Foundation

enum SetKind: String, Codable, CaseIterable, Identifiable {
    case work, warmup, dropset
    var id: String { rawValue }
}

struct Exercise: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var primaryMuscle: String?
    var equipment: String?

    init(id: UUID = UUID(), name: String, primaryMuscle: String? = nil, equipment: String? = nil) {
        self.id = id
        self.name = name
        self.primaryMuscle = primaryMuscle
        self.equipment = equipment
    }
}

struct WorkoutSet: Identifiable, Codable, Hashable {
    let id: UUID
    var reps: Int
    var weight: Double
    var rpe: Double? = nil
    var kind: SetKind = .work
    var secondsRest: Int? = 90
    var notes: String? = nil

    init(id: UUID = UUID(), reps: Int = 8, weight: Double = 50, rpe: Double? = nil, kind: SetKind = .work, secondsRest: Int? = 90, notes: String? = nil) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.rpe = rpe
        self.kind = kind
        self.secondsRest = secondsRest
        self.notes = notes
    }
}

struct ExerciseLog: Identifiable, Codable, Hashable {
    let id: UUID
    var exercise: Exercise
    var supersetGroup: UUID? = nil
    var sets: [WorkoutSet]

    init(id: UUID = UUID(), exercise: Exercise, sets: [WorkoutSet] = []) {
        self.id = id
        self.exercise = exercise
        self.sets = sets
    }
}

struct Workout: Identifiable, Codable, Hashable {
    let id: UUID
    var date: Date
    var exercises: [ExerciseLog]
    var completed: Bool

    init(id: UUID = UUID(), date: Date = Date(), exercises: [ExerciseLog] = [], completed: Bool = false) {
        self.id = id
        self.date = date
        self.exercises = exercises
        self.completed = completed
    }
}

struct ExerciseTemplate: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var sets: [WorkoutSet]

    init(id: UUID = UUID(), name: String, sets: [WorkoutSet] = [WorkoutSet()]) {
        self.id = id
        self.name = name
        self.sets = sets
    }
}

struct WorkoutTemplate: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var exercises: [ExerciseTemplate]

    init(id: UUID = UUID(), name: String, exercises: [ExerciseTemplate]) {
        self.id = id
        self.name = name
        self.exercises = exercises
    }
}

struct ExercisePR: Codable, Hashable {
    var heaviestWeight: Double = 0
    var mostReps: Int = 0
    var bestOneRM: Double = 0
}
