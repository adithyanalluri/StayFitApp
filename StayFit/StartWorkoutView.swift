import SwiftUI

struct StartWorkoutView: View {
    // MARK: Environment
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var timer: TimerManager

    // MARK: State
    @State var currentWorkout: Workout
    @State private var completions: [UUID: Bool] = [:]

    // Explicit init so all call-sites pass the model
    init(currentWorkout: Workout) { _currentWorkout = State(initialValue: currentWorkout) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Header (date)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                            Text(currentWorkout.date, style: .date)
                            Spacer()
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    // Exercises
                    VStack(spacing: 12) {
                        ForEach(currentWorkout.exercises.indices, id: \.self) { idx in
                            ExerciseCardView(
                                title: currentWorkout.exercises[idx].exercise.name,
                                sets: $currentWorkout.exercises[idx].sets,
                                completions: $completions,
                                onAddSet: { addSet(to: idx) }
                            )
                            .environmentObject(settings)
                            .environmentObject(timer)
                            .environmentObject(store)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Workout")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") { finishAndExit() }
                        .bold()
                }
            }
            // Floating timer pill
            .safeAreaInset(edge: .top) {
                RestTimerWidget()
                    .environmentObject(timer)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: Actions

    private func finishAndExit() {
        var w = currentWorkout
        w.completed = true
        store.saveWorkout(w)      // your Storage.swift method
        dismiss()                 // pop back
    }

    private func addSet(to exerciseIndex: Int) {
        let last = currentWorkout.exercises[exerciseIndex].sets.last
        let new = WorkoutSet(
            reps: last?.reps ?? 8,
            weight: last?.weight ?? 50,
            rpe: nil,
            kind: .work,
            secondsRest: last?.secondsRest ?? settings.defaultRestSeconds,
            notes: nil
        )
        currentWorkout.exercises[exerciseIndex].sets.append(new)

        let secs = new.secondsRest ?? settings.defaultRestSeconds
        timer.start(seconds: secs)
    }
}

// MARK: - Exercise Card (unchanged from your working version)
private struct ExerciseCardView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var timer: TimerManager
    @EnvironmentObject var store: DataStore

    let title: String
    @Binding var sets: [WorkoutSet]
    @Binding var completions: [UUID: Bool]
    let onAddSet: () -> Void

    @State private var showDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button { showDetail = true } label: {
                    Text(title)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.blue)
                        .underline()
                }
                .buttonStyle(.plain)

                Spacer()
                Button { } label: { Image(systemName: "chart.line.uptrend.xyaxis") }
                    .buttonStyle(.plain)
                Button { } label: { Image(systemName: "ellipsis.circle") }
                    .buttonStyle(.plain)
            }

            HStack {
                Text("Set").frame(width: 40, alignment: .leading)
                Text("Previous").frame(maxWidth: .infinity, alignment: .leading)
                Text(settings.unit.label.lowercased()).frame(width: 70)
                Text("Reps").frame(width: 60)
                Text("✓").frame(width: 30)
            }
            .foregroundStyle(.secondary)
            .font(.subheadline)

            ForEach(Array(sets.indices), id: \.self) { i in
                let id = sets[i].id
                HStack(spacing: 10) {

                    let tag = sets[i].kind == .warmup ? "W" : "\(i + 1)"
                    Text(tag)
                        .font(.subheadline)
                        .frame(width: 40, alignment: .leading)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(sets[i].kind == .warmup ? Color.orange.opacity(0.15) : Color.gray.opacity(0.12))
                        )

                    Text(previousText(forIndex: i))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    let displayWeight = settings.toDisplayWeight(kg: sets[i].weight)
                    TextField(
                        "0",
                        value: Binding(
                            get: { displayWeight },
                            set: { newVal in sets[i].weight = settings.fromDisplayWeight(newVal) }
                        ),
                        format: .number.precision(.fractionLength(0))
                    )
                    .keyboardType(.decimalPad)
                    .padding(.vertical, 10)
                    .frame(width: 70)
                    .multilineTextAlignment(.center)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.thinMaterial))

                    TextField("0", value: $sets[i].reps, format: .number)
                        .keyboardType(.numberPad)
                        .padding(.vertical, 10)
                        .frame(width: 60)
                        .multilineTextAlignment(.center)
                        .background(RoundedRectangle(cornerRadius: 10).fill(.thinMaterial))

                    Button {
                        completions[id] = !(completions[id] ?? false)
                    } label: {
                        Image(systemName: (completions[id] ?? false) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle((completions[id] ?? false) ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                .font(.body)
            }

            Button { onAddSet() } label: {
                Text("+ Add Set (\(formatted(settings.defaultRestSeconds)))")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.15)))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.black.opacity(0.06)))
        .sheet(isPresented: $showDetail) {
            ExerciseDetailView(exerciseName: title)
        }
    }

    private func formatted(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        return "\(m):" + String(format: "%02d", s)
    }

    private func previousText(forIndex index: Int) -> String {
        guard let latest = store.workouts.first(where: { $0.completed && $0.exercises.contains(where: { $0.exercise.name == title }) }),
              let log = latest.exercises.first(where: { $0.exercise.name == title }) else { return "—" }
        let s = index < log.sets.count ? log.sets[index] : log.sets.last
        guard let set = s else { return "—" }
        let w = Int(settings.toDisplayWeight(kg: set.weight))
        return "\(w) \(settings.unit.label.lowercased()) × \(set.reps)\(set.kind == .warmup ? " (W)" : "")"
    }
}
