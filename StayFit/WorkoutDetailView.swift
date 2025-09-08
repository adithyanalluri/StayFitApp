import SwiftUI

struct WorkoutDetailView: View {
    let workout: Workout
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Summary card
                Card {
                    CardHeader("Summary") { EmptyView() }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(workout.date.formatted(date: .abbreviated, time: .shortened))
                        Text("\(workout.exercises.count) exercises")
                        Text("\(totalSets) total sets")
                            .foregroundStyle(.secondary)
                        }.font(.subheadline)
                }

                // Exercise cards
                ForEach(workout.exercises) { log in
                    Card {
                        CardHeader(log.exercise.name) { EmptyView() }
                            .padding(.bottom, 6)

                        // headers
                        HStack {
                            Text("Set").frame(width: 36, alignment: .leading)
                            Text(settings.unit.label.lowercased()).frame(width: 70)
                            Text("Reps").frame(width: 60)
                            Spacer()
                            Text("Type").frame(width: 50)
                        }
                        .foregroundStyle(.secondary)
                        .font(.subheadline)

                        ForEach(Array(log.sets.enumerated()), id: \.1.id) { idx, s in
                            HStack {
                                Text("\(idx+1)").frame(width: 36, alignment: .leading)
                                Text("\(Int(settings.toDisplayWeight(kg: s.weight)))")
                                    .frame(width: 70)
                                Text("\(s.reps)").frame(width: 60)
                                Spacer()
                                Text(s.kind == .warmup ? "WU" : "Work")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 50)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Workout")
    }

    private var totalSets: Int {
        workout.exercises.reduce(0) { $0 + $1.sets.count }
    }
}
