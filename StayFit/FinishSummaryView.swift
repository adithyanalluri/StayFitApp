import SwiftUI


struct FinishSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var settings: SettingsStore
    @State var currentWorkout: Workout

    // Your log type
    let workout: Workout
    
    @State private var rating: Int = 0

    // MARK: - Computed summaries

    private var totalVolumeKG: Double {
        workout.exercises
            .flatMap(\.sets)
            .reduce(0) { sum, s in sum + (s.weight * Double(s.reps)) }
    }

    private var totalVolumeDisplay: String {
        let w = settings.toDisplayWeight(kg: totalVolumeKG)
        return "\(Int(w.rounded())) \(settings.unit.label)"
    }

    private var exerciseCount: Int { workout.exercises.count }

    private var setCount: Int {
        workout.exercises.reduce(0) { $0 + $1.sets.count }
    }

    // Per-exercise best set today + PR flag vs historical best
    private var rows: [ExerciseRow] {
        workout.exercises.map { log in
            let bestToday = log.sets.max { lhs, rhs in
                lhs.weight * Double(lhs.reps) < rhs.weight * Double(rhs.reps)
            }
            let todayScore = (bestToday?.weight ?? 0) * Double(bestToday?.reps ?? 0)

            let pastBest = bestScore(forExerciseNamed: log.exercise.name, before: workout.date)
            let isPR = todayScore > pastBest.score + 0.0001

            return ExerciseRow(
                name: log.exercise.name,
                bestWeightKG: bestToday?.weight ?? 0,
                bestReps: bestToday?.reps ?? 0,
                isPR: isPR
            )
        }
        .sorted { $0.name < $1.name }
    }

    // MARK: - UI

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Label("Date", systemImage: "calendar")
                        Spacer()
                        Text(workout.date, style: .date)
                    }
                    HStack {
                        Label("Exercises", systemImage: "list.bullet")
                        Spacer()
                        Text("\(exerciseCount)").monospacedDigit()
                    }
                    HStack {
                        Label("Sets", systemImage: "number")
                        Spacer()
                        Text("\(setCount)").monospacedDigit()
                    }
                    HStack {
                        Label("Volume", systemImage: "scalemass")
                        Spacer()
                        Text(totalVolumeDisplay).monospacedDigit()
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How would you rate this workout?")
                            .font(.headline)
                        HStack(spacing: 10) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: rating >= star ? "star.fill" : "star")
                                    .font(.system(size: 32))
                                    .foregroundColor(rating >= star ? .yellow : .gray)
                                    .onTapGesture { rating = star }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Highlights") {
                    ForEach(rows) { r in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.name).font(.headline)
                                Text("\(displayInt(r.bestWeightKG)) \(settings.unit.label.lowercased()) × \(r.bestReps)")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if r.isPR {
                                Label("PR", systemImage: "sparkles")
                                    .foregroundStyle(.orange)
                                    .labelStyle(.titleAndIcon)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Workout Summary")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveFinishedWorkout()
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }

    // MARK: - Types
    struct ExerciseRow: Identifiable {
        let id = UUID()
        let name: String
        let bestWeightKG: Double
        let bestReps: Int
        let isPR: Bool
    }

    // MARK: - Local helpers (no global extensions)

    /// Convert kg to user's display unit and format as an Int.
    private func displayInt(_ kg: Double) -> Int {
        Int(settings.toDisplayWeight(kg: kg).rounded())
    }

    /// Return best (weight * reps) for an exercise before a given date by scanning past workouts.
    private func bestScore(forExerciseNamed name: String, before: Date) -> (score: Double, weightKG: Double, reps: Int) {
        var best: (Double, Double, Int) = (0, 0, 0)
        for w in store.workouts where w.date < before {
            if let log = w.exercises.first(where: { $0.exercise.name == name }) {
                for s in log.sets {
                    let score = s.weight * Double(s.reps)
                    if score > best.0 { best = (score, s.weight, s.reps) }
                }
            }
        }
        return best
    }

    /// Hand off to DataStore so it can mark complete and persist internally.
    private func saveFinishedWorkout() {
        var ratedWorkout = workout
        ratedWorkout.rating = rating
        store.saveCompleted(ratedWorkout)
    }
}

