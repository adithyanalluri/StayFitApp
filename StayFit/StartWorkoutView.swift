import SwiftUI
import WidgetKit

struct StartWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var timer: TimerManager

    @State var currentWorkout: Workout
    @State private var completions: [UUID: Bool] = [:]
    @State private var showFinishConfirm = false
    @State private var showPicker = false

    init(currentWorkout: Workout) {
        _currentWorkout = State(initialValue: currentWorkout)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Fixed header
                VStack(spacing: 12) {
                    HStack {
                        Button {
                            showFinishConfirm = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Finish Workout")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(.green)
                            )
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(currentWorkout.date, style: .date)
                                .font(.system(size: 14, weight: .medium))
                            Text(currentWorkout.date, style: .time)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Rest timer widget
                    if timer.isVisible {
                        RestTimerWidget()
                            .environmentObject(timer)
                    }
                }
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                
                // Scrollable exercises or empty state with add button
                ScrollView {
                    VStack(spacing: 16) {
                        if currentWorkout.exercises.isEmpty {
                            VStack(spacing: 20) {
                                EmptyWorkoutView()
                                Button {
                                    showPicker = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                        Text("Add Exercise")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 14)
                                    .background(
                                        Capsule()
                                            .fill(Color.blue)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            ForEach(currentWorkout.exercises.indices, id: \.self) { idx in
                                ExerciseCardView(
                                    exercise: $currentWorkout.exercises[idx],
                                    completions: $completions,
                                    onAddSet: { addSet(to: idx) },
                                    onSetCompleted: { setId in
                                        handleSetCompletion(exerciseIndex: idx, setId: setId)
                                    }
                                )
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Cancel")
                    }
                }
            }
        }
        .confirmationDialog("Finish Workout", isPresented: $showFinishConfirm) {
            Button("Save & Finish") {
                finishWorkout()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Save this workout to your history?")
        }
        .sheet(isPresented: $showPicker) {
            ExercisePickerView { selectedExercise in
                currentWorkout.exercises.append(ExerciseLog(exercise: selectedExercise, sets: []))
                showPicker = false
            }
        }
        .onAppear {
            updateWidgetExerciseContext()
        }
    }

    private func addSet(to exerciseIndex: Int) {
        let last = currentWorkout.exercises[exerciseIndex].sets.last
        let new = WorkoutSet(
            reps: last?.reps ?? 10,
            weight: last?.weight ?? 22.68,
            rpe: nil,
            kind: .work,
            secondsRest: last?.secondsRest ?? settings.defaultRestSeconds,
            notes: nil
        )
        currentWorkout.exercises[exerciseIndex].sets.append(new)
        updateWidgetExerciseContext(currentExerciseIndex: exerciseIndex)
    }
    
    private func handleSetCompletion(exerciseIndex: Int, setId: UUID) {
        // Haptic feedback when logging set
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
        
        // Toggle completion
        let isNowCompleted = completions[setId] ?? false
        completions[setId] = !isNowCompleted
        
        updateWidgetExerciseContext(currentExerciseIndex: exerciseIndex)
        
        // If set was just completed (checked), start rest timer
        if !isNowCompleted {
            if let set = currentWorkout.exercises[exerciseIndex].sets.first(where: { $0.id == setId }) {
                let restTime = set.secondsRest ?? settings.defaultRestSeconds
                timer.start(seconds: restTime)
                if let defaults = UserDefaults(suiteName: "group.com.yourcompany.stayfit") { defaults.set(restTime, forKey: "widget_timer_remaining"); defaults.synchronize() }
            }
        }
    }

    private func finishWorkout() {
        var w = currentWorkout
        w.completed = true
        store.saveWorkout(w)
        dismiss()
    }
    
    private func updateWidgetExerciseContext(currentExerciseIndex: Int? = nil, currentSetIndex: Int? = nil) {
        guard let defaults = UserDefaults(suiteName: "group.com.yourcompany.stayfit") else { return }

        // Determine current exercise and set
        let exerciseIdx = currentExerciseIndex ?? currentWorkout.exercises.indices.first
        var exerciseName = ""
        var setNumber = 0
        var totalSets = 0
        var reps = 0
        var weight: Double = 0

        if let eIdx = exerciseIdx, currentWorkout.exercises.indices.contains(eIdx) {
            let exerciseLog = currentWorkout.exercises[eIdx]
            exerciseName = exerciseLog.exercise.name
            totalSets = exerciseLog.sets.count

            // Prefer provided set index, otherwise find first incomplete set, else last
            let sIdx: Int
            if let provided = currentSetIndex, exerciseLog.sets.indices.contains(provided) {
                sIdx = provided
            } else if let firstIncomplete = exerciseLog.sets.firstIndex(where: { !(completions[$0.id] ?? false) }) {
                sIdx = firstIncomplete
            } else {
                sIdx = max(exerciseLog.sets.count - 1, 0)
            }

            if exerciseLog.sets.indices.contains(sIdx) {
                let set = exerciseLog.sets[sIdx]
                setNumber = sIdx + 1
                reps = set.reps
                weight = settings.toDisplayWeight(kg: set.weight)
            }
        }

        // Write values to shared defaults (widget reads these keys)
        defaults.set(exerciseName, forKey: "widget_exercise_name")
        defaults.set(setNumber, forKey: "widget_set_number")
        defaults.set(totalSets, forKey: "widget_total_sets")
        defaults.set(reps, forKey: "widget_reps")
        defaults.set(weight, forKey: "widget_weight")

        // Timer remaining is kept in sync by TimerManager via group defaults
        // Trigger a simple reload hint for widgets
        defaults.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Empty State
struct EmptyWorkoutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "dumbbell")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Exercises Added")
                .font(.title2.bold())
            
            Text("Add exercises to start your workout")
                .foregroundStyle(.secondary)
        }
        .padding(.top, 100)
    }
}

// MARK: - Exercise Card
struct ExerciseCardView: View {
    @Binding var exercise: ExerciseLog
    @Binding var completions: [UUID: Bool]
    let onAddSet: () -> Void
    let onSetCompleted: (UUID) -> Void
    
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var store: DataStore
    @State private var showDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Button {
                    showDetail = true
                } label: {
                    Text(exercise.exercise.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Menu {
                    Button("View Details", action: { showDetail = true })
                    Button("Remove Exercise", role: .destructive, action: {})
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color(.systemGray5)))
                }
            }
            
            // Sets table
            VStack(spacing: 8) {
                // Headers
                HStack {
                    Text("SET").frame(width: 40, alignment: .leading)
                    Text("PREVIOUS").frame(maxWidth: .infinity, alignment: .leading)
                    Text(settings.unit.label).frame(width: 70, alignment: .center)
                    Text("REPS").frame(width: 60, alignment: .center)
                    Text("✓").frame(width: 36, alignment: .center)
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                
                // Set rows
                ForEach(Array(exercise.sets.indices), id: \.self) { i in
                    SetRow(
                        set: $exercise.sets[i],
                        setNumber: i + 1,
                        isCompleted: completions[exercise.sets[i].id] ?? false,
                        previousText: previousText(forIndex: i),
                        onComplete: { onSetCompleted(exercise.sets[i].id) }
                    )
                }
            }
            
            // Add set button
            Button(action: onAddSet) {
                HStack {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Add Set")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue.opacity(0.1))
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .sheet(isPresented: $showDetail) {
            ExerciseDetailView(exerciseName: exercise.exercise.name)
        }
    }
    
    private func previousText(forIndex index: Int) -> String {
        guard let latest = store.workouts.first(where: {
            $0.completed && $0.exercises.contains(where: { $0.exercise.name == exercise.exercise.name })
        }),
        let log = latest.exercises.first(where: { $0.exercise.name == exercise.exercise.name })
        else { return "—" }
        
        let s = index < log.sets.count ? log.sets[index] : log.sets.last
        guard let set = s else { return "—" }
        
        let w = Int(settings.toDisplayWeight(kg: set.weight))
        return "\(w) × \(set.reps)"
    }
}

// MARK: - Set Row
struct SetRow: View {
    @Binding var set: WorkoutSet
    let setNumber: Int
    let isCompleted: Bool
    let previousText: String
    let onComplete: () -> Void
    
    @EnvironmentObject var settings: SettingsStore
    
    var body: some View {
        HStack(spacing: 8) {
            // Set number
            Text(set.kind == .warmup ? "W" : "\(setNumber)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(set.kind == .warmup ? .orange : .primary)
                .frame(width: 40, alignment: .leading)
            
            // Previous
            Text(previousText)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Weight
            TextField("", value: Binding(
                get: { settings.toDisplayWeight(kg: set.weight) },
                set: { newVal in set.weight = settings.fromDisplayWeight(newVal) }
            ), format: .number.precision(.fractionLength(0)))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 16, weight: .medium))
            .frame(width: 70)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
            
            // Reps
            TextField("", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 60)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
            
            // Checkmark
            Button(action: onComplete) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 36)
        }
    }
}

