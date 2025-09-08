import Foundation

@MainActor
final class DataStore: ObservableObject {
    @Published var workouts: [Workout] = []
    @Published var exercisesMaster: [Exercise] = []
    @Published var templates: [WorkoutTemplate] = []
    @Published var prs: [String: ExercisePR] = [:]

    private let workoutsURL: URL
    private let exercisesURL: URL
    private let templatesURL: URL
    private let prsURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.workoutsURL = docs.appendingPathComponent("workouts.json")
        self.exercisesURL = docs.appendingPathComponent("exercises.json")
        self.templatesURL = docs.appendingPathComponent("templates.json")
        self.prsURL = docs.appendingPathComponent("prs.json")
        Task { await load() }
    }

    func load() async {
        do {
            if let data = try? Data(contentsOf: workoutsURL) {
                self.workouts = try JSONDecoder().decode([Workout].self, from: data)
            }
            if let data = try? Data(contentsOf: exercisesURL) {
                self.exercisesMaster = try JSONDecoder().decode([Exercise].self, from: data)
            }
            if let data = try? Data(contentsOf: templatesURL) {
                self.templates = try JSONDecoder().decode([WorkoutTemplate].self, from: data)
            }
            if let data = try? Data(contentsOf: prsURL) {
                self.prs = try JSONDecoder().decode([String: ExercisePR].self, from: data)
            }
        } catch { print("Load error:", error) }
    }

    private func persist() {
        do {
            try JSONEncoder().encode(workouts).write(to: workoutsURL, options: [.atomic])
            try JSONEncoder().encode(exercisesMaster).write(to: exercisesURL, options: [.atomic])
            try JSONEncoder().encode(templates).write(to: templatesURL, options: [.atomic])
            try JSONEncoder().encode(prs).write(to: prsURL, options: [.atomic])
        } catch { print("Persist error:", error) }
    }

    func addExerciseToMaster(name: String) -> Exercise {
        if let existing = exercisesMaster.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return existing
        }
        let new = Exercise(name: name)
        exercisesMaster.append(new)
        persist()
        return new
    }

    func saveWorkout(_ workout: Workout) {
        if let idx = workouts.firstIndex(where: { $0.id == workout.id }) {
            workouts[idx] = workout
        } else {
            workouts.insert(workout, at: 0)
        }
        if workout.completed { updatePRs(from: workout) }
        persist()
    }
    func saveCompleted(_ workout: Workout) {
        var w = workout
        w.completed = true
        // Reuse your existing save path (updates PRs + persists)
        saveWorkout(w)
    }
    func deleteWorkout(at offsets: IndexSet) {
        workouts.remove(atOffsets: offsets)
        persist()
    }

    func saveTemplate(_ template: WorkoutTemplate) {
        if let idx = templates.firstIndex(where: { $0.id == template.id }) {
            templates[idx] = template
        } else {
            templates.insert(template, at: 0)
        }
        persist()
    }

    func deleteTemplate(at offsets: IndexSet) {
        templates.remove(atOffsets: offsets)
        persist()
    }

    func instantiateWorkout(from template: WorkoutTemplate) -> Workout {
        var logs: [ExerciseLog] = []
        for t in template.exercises {
            let ex = addExerciseToMaster(name: t.name)
            let log = ExerciseLog(exercise: ex, sets: t.sets)
            logs.append(log)
        }
        return Workout(exercises: logs, completed: false)
    }

    private func epley1RM(weight: Double, reps: Int) -> Double {
        guard reps > 0 else { return 0 }
        return weight * (1.0 + Double(reps) / 30.0)
    }

    private func updatePRs(from workout: Workout) {
        for log in workout.exercises {
            let name = log.exercise.name
            var current = prs[name] ?? ExercisePR()
            for s in log.sets {
                current.heaviestWeight = max(current.heaviestWeight, s.weight)
                current.mostReps = max(current.mostReps, s.reps)
                current.bestOneRM = max(current.bestOneRM, epley1RM(weight: s.weight, reps: s.reps))
            }
            prs[name] = current
        }
    }
}
