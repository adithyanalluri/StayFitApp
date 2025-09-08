import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: DataStore

    var body: some View {
        NavigationStack {
            if store.workouts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No workouts yet").font(.headline)
                    Text("Finish a workout from the Log tab and it will show up here.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
                .navigationTitle("History")
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(store.workouts) { w in
                            NavigationLink {
                                WorkoutDetailView(workout: w)
                            } label: {
                                Card {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle().fill(Color.blue.opacity(0.15))
                                            Image(systemName: "dumbbell.fill")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(.blue)
                                        }
                                        .frame(width: 36, height: 36)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(w.date, style: .date).font(.headline)
                                            Text("\(w.exercises.count) exercises • \(totalSets(w)) sets")
                                                .foregroundStyle(.secondary)
                                                .font(.subheadline)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) { delete(workout: w) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle("History")
            }
        }
    }

    private func totalSets(_ w: Workout) -> Int {
        w.exercises.reduce(0) { $0 + $1.sets.count }
    }

    private func delete(workout: Workout) {
        if let idx = store.workouts.firstIndex(where: { $0.id == workout.id }) {
            store.workouts.remove(at: idx)
        }
    }
}
