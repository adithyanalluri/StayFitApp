import WidgetKit
import SwiftUI

// MARK: - Timeline Entry
struct WorkoutEntry: TimelineEntry {
    let date: Date
    let exerciseName: String
    let setNumber: Int
    let totalSets: Int
    let reps: Int
    let weight: Double
    let timerRemaining: Int?
}

// MARK: - Provider
struct WorkoutProvider: TimelineProvider {
    func placeholder(in context: Context) -> WorkoutEntry {
        WorkoutEntry(date: Date(), exerciseName: "Bench Press", setNumber: 1, totalSets: 3, reps: 10, weight: 135, timerRemaining: 60)
    }

    func getSnapshot(in context: Context, completion: @escaping (WorkoutEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WorkoutEntry>) -> Void) {
        let entry = loadEntry()
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30)))
        completion(timeline)
    }

    private func loadEntry() -> WorkoutEntry {
        let defaults = UserDefaults(suiteName: "group.com.yourcompany.stayfit")
        let exerciseName = defaults?.string(forKey: "widget_exercise_name") ?? "Bench Press"
        let setNumber = defaults?.integer(forKey: "widget_set_number") ?? 1
        let totalSets = defaults?.integer(forKey: "widget_total_sets") ?? 3
        let reps = defaults?.integer(forKey: "widget_reps") ?? 10
        let weight = defaults?.double(forKey: "widget_weight") ?? 135
        let timerRemaining = defaults?.integer(forKey: "widget_timer_remaining")
        return WorkoutEntry(
            date: Date(),
            exerciseName: exerciseName,
            setNumber: (setNumber == 0 ? 1 : setNumber),
            totalSets: (totalSets == 0 ? 3 : totalSets),
            reps: (reps == 0 ? 10 : reps),
            weight: (weight == 0 ? 135 : weight),
            timerRemaining: (timerRemaining == 0 ? nil : timerRemaining)
        )
    }
}

// MARK: - Widget View
struct WorkoutWidgetEntryView: View {
    var entry: WorkoutEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(entry.exerciseName)
                .font(.title2.bold())
            HStack {
                VStack(alignment: .leading) {
                    Text("Set \(entry.setNumber) of \(entry.totalSets)").font(.subheadline)
                    HStack {
                        Text("Weight: \(Int(entry.weight)) lbs").font(.caption)
                        Text("Reps: \(entry.reps)").font(.caption)
                    }
                }
                Spacer()
                if let timer = entry.timerRemaining {
                    VStack {
                        Image(systemName: "timer")
                        Text("\(timer)s")
                            .font(.caption)
                    }
                }
            }
            // Removed AppIntentButton since intents are not used here
        }
        .padding()
    }
}

// MARK: - Widget
struct StayFitWidgets: Widget {
    let kind: String = "StayFitWidgets"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WorkoutProvider()) { entry in
            WorkoutWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Workout Control")
        .description("Quickly view progress and complete sets.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
