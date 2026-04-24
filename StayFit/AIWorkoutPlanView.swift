import SwiftUI
import FoundationModels

enum WorkoutLocation: String, CaseIterable, Identifiable {
    case home, gym
    var id: String { rawValue }
    var label: String { self == .home ? "Home" : "Commercial Gym" }
}

struct AIWorkoutPlanView: View {
    @EnvironmentObject var store: DataStore

    // Minimal inputs
    @State private var location: WorkoutLocation = .home
    @State private var daysPerWeek: Int = 3

    // Output / state
    @State private var isGenerating = false
    @State private var error: String?
    @State private var routineName: String = "My AI Routine"
    @State private var generatedText: String = ""
    @State private var generatedWorkout: Workout? = nil

    // Multi-day plan storage
    @State private var generatedDays: [String] = []
    @State private var dayPlans: [[ExerciseLog]] = []

    // Replacement sheet context
    @State private var replacementIndex: Int? = nil
    @State private var showingReplacementSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if let workout = generatedWorkout {
                    planView(workout: workout)
                } else {
                    inputView
                }
            }
            .navigationTitle("AI Workout Plan")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
        }
    }

    // Disable saving when no exercises
    private var saveDisabled: Bool {
        generatedDays.isEmpty ? (generatedWorkout?.exercises.isEmpty ?? true) : dayPlans.allSatisfy { $0.isEmpty }
    }

    // MARK: - Input View (Minimal)
    private var inputView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Just pick where you'll work out. We'll do the rest.")
                    .foregroundStyle(.secondary)

                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Where will you work out?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Picker("Location", selection: $location) {
                            ForEach(WorkoutLocation.allCases) { loc in
                                Text(loc.label).tag(loc)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        Stepper(value: $daysPerWeek, in: 1...6) {
                            HStack {
                                Text("Days per week")
                                Spacer()
                                Text("\(daysPerWeek)")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Button {
                    Task { await generatePlan() }
                } label: {
                    HStack {
                        if isGenerating { ProgressView() }
                        Text(isGenerating ? "Generating..." : "Generate My Plan")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isGenerating)

                if let error = error {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: 700)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Generated Plan View
    @ViewBuilder
    private func planView(workout: Workout) -> some View {
        List {
            if !generatedDays.isEmpty {
                ForEach(Array(generatedDays.enumerated()), id: \.0) { i, dayName in
                    Section(dayName) {
                        let logs = i < dayPlans.count ? dayPlans[i] : []
                        ForEach(logs.indices, id: \.self) { idx in
                            HStack {
                                Text(logs[idx].exercise.name)
                                Spacer()
                                Button("Need a replacement?") {
                                    replacementIndex = idx
                                    showingReplacementSheet = true
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            } else {
                Section("Your Plan") {
                    ForEach(workout.exercises.indices, id: \.self) { idx in
                        HStack {
                            Text(workout.exercises[idx].exercise.name)
                            Spacer()
                            Button("Need a replacement?") {
                                replacementIndex = idx
                                showingReplacementSheet = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            if !generatedText.isEmpty {
                Section("Details") {
                    ScrollView(.horizontal) {
                        Text(generatedText)
                            .font(.system(.body, design: .monospaced))
                            .padding(.vertical, 4)
                    }
                }
            }

            Section("Save or Share") {
                TextField("Routine Name", text: $routineName)
                    .textFieldStyle(.roundedBorder)
                Button("Save as Routine") { saveRoutine() }
                    .disabled(saveDisabled)
                Button("Copy Plan Text") { UIPasteboard.general.string = generatedText }
                    .disabled(generatedText.isEmpty)
            }
        }
        .sheet(isPresented: $showingReplacementSheet) {
            if let idx = replacementIndex, !generatedDays.isEmpty {
                // Replacement for multi-day plan: find day containing index - ambiguous, so fallback to first day
                if let firstDayLogs = dayPlans.first, firstDayLogs.indices.contains(idx) {
                    ReplacementSheet(
                        original: firstDayLogs[idx],
                        location: location
                    ) { newLog in
                        replaceExercise(at: idx, with: newLog)
                    }
                } else {
                    NavigationStack {
                        VStack(spacing: 16) {
                            Text("No exercise selected.")
                                .font(.headline)
                            Button("Dismiss") { showingReplacementSheet = false }
                        }
                        .padding()
                        .navigationTitle("Pick a Replacement")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                }
            } else if let idx = replacementIndex, let workout = generatedWorkout, workout.exercises.indices.contains(idx) {
                ReplacementSheet(
                    original: workout.exercises[idx],
                    location: location
                ) { newLog in
                    replaceExercise(at: idx, with: newLog)
                }
            } else {
                NavigationStack {
                    VStack(spacing: 16) {
                        Text("No exercise selected.")
                            .font(.headline)
                        Button("Dismiss") { showingReplacementSheet = false }
                    }
                    .padding()
                    .navigationTitle("Pick a Replacement")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }

    // MARK: - Generation
    private func generatePlan() async {
        isGenerating = true
        error = nil
        generatedText = ""
        generatedWorkout = nil
        generatedDays = []
        dayPlans = []

        // Try on-device LLM first if available (iOS 26+)
        if #available(iOS 26.0, *) {
            do {
                let model = SystemLanguageModel.default
                guard case .available = model.availability else {
                    throw NSError(domain: "AI", code: -1, userInfo: [NSLocalizedDescriptionKey: "AI not available on this device."])
                }

                let session = LanguageModelSession(instructions: "You are an expert personal trainer. Create a simple, beginner-friendly workout session for the chosen environment. Use only common equipment for a commercial gym, or bodyweight/minimal gear for home. Respond with a short bullet list of 5–6 exercises with sets x reps. Keep it concise.")
                let prompt = "Location: \(location == .home ? "Home" : "Commercial Gym").\nDays per week: \(daysPerWeek).\nGenerate a per-day program where each session is about 60 minutes. Choose an efficient split based on days per week (2=Upper/Lower, 3=PPL, 4=Upper/Lower x2, 5=PPL+UL, 6=PPL x2). For each day, list 5–7 exercises with sets x reps. Keep it concise."
                let response = try await session.respond(to: prompt)
                await MainActor.run {
                    self.generatedText = response.content
                    self.parseAIDays(from: response.content)
                }
            } catch {
                await MainActor.run { self.error = error.localizedDescription }
            }
        } else {
            await MainActor.run {
                self.error = "AI is only available on iOS 26 and newer."
            }
        }

        // Regardless of text, also seed a structured Workout so the UI is actionable.
        await MainActor.run {
            self.generatedWorkout = SimplePlanBuilder.build(location: self.location, daysPerWeek: self.daysPerWeek)
            // Also set generatedDays and dayPlans fallback if empty (AI unavailable or parse failed)
            if self.generatedDays.isEmpty {
                self.generatedDays = SimplePlanBuilder.splitForDays(self.daysPerWeek)
                self.dayPlans = self.generatedDays.map { day in
                    SimplePlanBuilder.exercisesFor(dayType: day, location: self.location)
                        .map { ExerciseLog(exercise: Exercise(name: $0), sets: []) }
                }
            }
            self.isGenerating = false
        }
    }

    private func replaceExercise(at index: Int, with newLog: ExerciseLog) {
        if !generatedDays.isEmpty {
            // Attempt to find which day contains index, fallback to first day
            for dayIndex in dayPlans.indices {
                if dayPlans[dayIndex].indices.contains(index) {
                    var dayLogs = dayPlans[dayIndex]
                    dayLogs[index] = newLog
                    dayPlans[dayIndex] = dayLogs
                    return
                }
            }
            // If not found, fallback to first day index replace if possible
            if !dayPlans.isEmpty && dayPlans[0].indices.contains(index) {
                var dayLogs = dayPlans[0]
                dayLogs[index] = newLog
                dayPlans[0] = dayLogs
            }
        } else {
            guard var plan = generatedWorkout, plan.exercises.indices.contains(index) else { return }
            plan.exercises[index] = newLog
            generatedWorkout = plan
        }
    }

    private func saveRoutine() {
        if !generatedDays.isEmpty {
            // Flatten into a single template with day headers in names
            var templates: [ExerciseTemplate] = []
            for (i, day) in generatedDays.enumerated() {
                let logs = i < dayPlans.count ? dayPlans[i] : []
                templates.append(contentsOf: logs.map { ExerciseTemplate(name: "\(day): \($0.exercise.name)") })
            }
            let template = WorkoutTemplate(name: routineName.isEmpty ? "AI Routine" : routineName, exercises: templates)
            store.saveTemplate(template)
        } else if let workout = generatedWorkout {
            let templates = workout.exercises.map { ExerciseTemplate(name: $0.exercise.name) }
            let template = WorkoutTemplate(name: routineName.isEmpty ? "AI Routine" : routineName, exercises: templates)
            store.saveTemplate(template)
        }
    }

    private func parseAIDays(from text: String) {
        // Very simple parser: look for lines starting with Day or known split names
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        var currentDay: String? = nil
        var days: [String] = []
        var plans: [[ExerciseLog]] = []

        func startDay(_ name: String) {
            days.append(name)
            plans.append([])
            currentDay = name
        }

        for line in lines where !line.isEmpty {
            let lower = line.lowercased()
            if lower.hasPrefix("day ") || lower.hasPrefix("push") || lower.hasPrefix("pull") || lower.hasPrefix("legs") || lower.hasPrefix("upper") || lower.hasPrefix("lower") || lower.hasPrefix("full body") {
                let title = line.replacingOccurrences(of: ":", with: "")
                startDay(title)
                continue
            }
            // bullet like "- Bench Press 3x8"
            if let idx = days.indices.last {
                // extract exercise name up to digits or x
                let namePart = line.split(separator: "-").last.map(String.init) ?? line
                let clean = namePart.trimmingCharacters(in: .whitespaces)
                // Extract name stopping before digits or x or sets
                let exName = clean.components(separatedBy: CharacterSet.decimalDigits).first?.trimmingCharacters(in: .whitespaces) ?? clean
                // Remove trailing 'x' or other trailing non-alpha characters
                let filteredName = exName.trimmingCharacters(in: CharacterSet(charactersIn: " xX"))
                if !filteredName.isEmpty {
                    let log = ExerciseLog(exercise: Exercise(name: filteredName), sets: [])
                    plans[idx].append(log)
                }
            }
        }
        self.generatedDays = days
        self.dayPlans = plans
    }
}

// MARK: - Simple Plan Builder (fallback/seed)
private enum SimplePlanBuilder {
    static func build(location: WorkoutLocation, daysPerWeek: Int) -> Workout {
        // Create a single Workout that contains all exercises for the first day as a seed
        // and also produce a readable summary in generatedText elsewhere. For now, we will
        // pack Day 1 into the structured workout so the UI remains actionable.
        let split = splitForDays(daysPerWeek)
        let day1Name = split.first ?? "Full Body"
        let names = exercisesFor(dayType: day1Name, location: location)
        let logs: [ExerciseLog] = names.map { ExerciseLog(exercise: Exercise(name: $0), sets: []) }
        return Workout(date: Date(), exercises: logs, completed: false)
    }

    static func splitForDays(_ d: Int) -> [String] {
        switch d {
        case 2: return ["Upper", "Lower"]
        case 3: return ["Push", "Pull", "Legs"]
        case 4: return ["Upper", "Lower", "Upper", "Lower"]
        case 5: return ["Push", "Pull", "Legs", "Upper", "Lower"]
        case 6: return ["Push", "Pull", "Legs", "Push", "Pull", "Legs"]
        default: return ["Full Body"]
        }
    }

    static func exercisesFor(dayType: String, location: WorkoutLocation) -> [String] {
        let isHome = (location == .home)
        switch dayType.lowercased() {
        case "push":
            return isHome ? ["Push-ups", "Pike Push-ups", "Dips (chairs)", "Incline Push-ups", "Triceps Extensions (band)"]
                          : ["Bench Press", "Overhead Press", "Incline DB Press", "Cable Fly", "Triceps Pushdown"]
        case "pull":
            return isHome ? ["Inverted Rows", "Pull-ups/Assisted", "Band Row", "Band Face Pull", "Biceps Curls (band)"]
                          : ["Lat Pulldown", "Seated Row", "Chest Supported Row", "Face Pull", "EZ-Bar Curl"]
        case "legs":
            return isHome ? ["Bodyweight Squats", "Split Squats", "Glute Bridge", "RDL (backpack)", "Calf Raises"]
                          : ["Barbell Squat", "Leg Press", "Romanian Deadlift", "Leg Curl", "Calf Raise"]
        case "upper":
            return isHome ? ["Push-ups", "Pike Push-ups", "Inverted Rows", "Band Row", "Biceps Curls (band)"]
                          : ["Bench Press", "Lat Pulldown", "Seated Row", "Overhead Press", "Cable Curl"]
        case "lower":
            return isHome ? ["Bodyweight Squats", "Split Squats", "Glute Bridge", "RDL (backpack)", "Calf Raises"]
                          : ["Barbell Squat", "Leg Press", "Romanian Deadlift", "Leg Curl", "Calf Raise"]
        case "full body":
            return isHome ? ["Push-ups", "Inverted Rows", "Bodyweight Squats", "Glute Bridge", "Plank"]
                          : ["Bench Press", "Lat Pulldown", "Barbell Squat", "Seated Row", "Leg Press"]
        default:
            return isHome ? ["Push-ups", "Inverted Rows", "Bodyweight Squats", "Glute Bridge", "Plank"]
                          : ["Bench Press", "Lat Pulldown", "Barbell Squat", "Seated Row", "Leg Press"]
        }
    }
}

// MARK: - Replacement Sheet
private struct ReplacementSheet: View {
    var original: ExerciseLog
    var location: WorkoutLocation
    var onPick: (ExerciseLog) -> Void

    var body: some View {
        NavigationStack {
            List {
                let items = suggestions()
                if items.isEmpty {
                    Section {
                        Text("No suggestions available for \(original.exercise.name).")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Alternatives for \(original.exercise.name)") {
                        ForEach(items, id: \.exercise.name) { suggestion in
                            Button { onPick(suggestion) } label: { Text(suggestion.exercise.name) }
                        }
                    }
                }
            }
            .navigationTitle("Pick a Replacement")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func suggestions() -> [ExerciseLog] {
        let key = original.exercise.name.lowercased()
        let names: [String]
        if location == .home {
            switch key {
            case "bench press":
                names = ["Push-ups", "Dumbbell Floor Press", "Incline Push-ups"]
            case "lat pulldown":
                names = ["Inverted Rows", "Resistance Band Pulldown", "Doorframe Rows"]
            default:
                names = ["Bodyweight Squats", "Split Squats", "Hip Hinge", "Glute Bridge"]
            }
        } else {
            switch key {
            case "push-ups":
                names = ["Chest Press Machine", "Bench Press", "Incline DB Press"]
            case "bodyweight squats":
                names = ["Leg Press", "Goblet Squat", "Hack Squat"]
            default:
                names = ["Seated Row", "Cable Row", "Lat Pulldown", "Machine Row"]
            }
        }
        return names.map { ExerciseLog(exercise: Exercise(name: $0), sets: original.sets) }
    }
}
