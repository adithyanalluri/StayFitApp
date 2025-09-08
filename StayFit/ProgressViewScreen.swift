import SwiftUI

struct ProgressViewScreen: View {
    @EnvironmentObject var store: DataStore

    // The Picker’s selection must always be one of the tags below
    @State private var selectedExercise: String = ""

    // Unique, sorted exercise names found across all saved workouts
    private var exerciseNames: [String] {
        let names = store.workouts.flatMap { $0.exercises.map { $0.exercise.name } }
        return Array(Set(names)).sorted()
    }

    // Simple sample “history” for the selected exercise (you can replace with your real data)
    private var history: [(date: Date, weight: Double, reps: Int)] {
        store.workouts
            .sorted(by: { $0.date < $1.date })
            .compactMap { w in
                guard let log = w.exercises.first(where: { $0.exercise.name == selectedExercise }),
                      let lastSet = log.sets.last else { return nil }
                return (w.date, lastSet.weight, lastSet.reps)
            }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {

                // ---- Picker (crash-proof) ----
                if exerciseNames.isEmpty {
                    Text("Log a workout to see progress here.")
                        .foregroundStyle(.secondary)
                        .padding(.top, 40)
                } else {
                    Picker("Exercise", selection: $selectedExercise) {
                        ForEach(exerciseNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal)
                    .onAppear {
                        if selectedExercise.isEmpty {
                            selectedExercise = exerciseNames.first ?? ""
                        }
                    }
                    // NEW iOS 17+ signature (oldValue, newValue)
                    .onChange(of: exerciseNames) { _, list in
                        if !list.contains(selectedExercise) {
                            selectedExercise = list.first ?? ""
                        }
                    }

                }

                // ---- Simple preview of data (replace with a chart when ready) ----
                if !selectedExercise.isEmpty, !history.isEmpty {
                    List {
                        Section("\(selectedExercise) — Recent Sets") {
                            ForEach(history.indices, id: \.self) { i in
                                let h = history[i]
                                HStack {
                                    Text(h.date, style: .date)
                                    Spacer()
                                    Text("\(Int(h.weight)) kg × \(h.reps)")
                                        .font(.body.monospacedDigit())
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                } else if !exerciseNames.isEmpty {
                    Text("No sets found yet for **\(selectedExercise)**.")
                        .foregroundStyle(.secondary)
                        .padding(.top, 20)
                }

                Spacer()
            }
            .navigationTitle("Progress")
        }
    }
}
