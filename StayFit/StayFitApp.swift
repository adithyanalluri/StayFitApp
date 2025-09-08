import SwiftUI
import UserNotifications

@main
struct StayFitApp: App {
    @StateObject private var store = DataStore()
    @StateObject private var settings = SettingsStore()
    @StateObject private var timer = TimerManager()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        // (Optional) register rest-timer actions you already had
        let add30  = UNNotificationAction(identifier: "ADD_30",    title: "+30s", options: [])
        let cancel = UNNotificationAction(identifier: "CANCEL_REST", title: "Stop", options: [.destructive])
        let cat = UNNotificationCategory(identifier: "REST_CATEGORY", actions: [add30, cancel], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([cat])
    }

    var body: some Scene {
        WindowGroup {
            // EITHER: your tabbed home
            HomeView()
                .environmentObject(store)
                .environmentObject(settings)
                .environmentObject(timer)
                .tint(Color.blue)                 // <- use Color.blue to avoid the 'blue' error

            // OR, if you don’t have HomeView yet, comment the block above
            // and temporarily launch straight into the workout:
            /*
            StartWorkoutView(currentWorkout: quickStartWorkout())
                .environmentObject(store)
                .environmentObject(settings)
                .environmentObject(timer)
                .tint(Color.blue)
            */
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                // timer manager already schedules local notif when resting
                break
            case .active:
                break
            default:
                break
            }
        }
    }
}
private func quickStartWorkout() -> Workout {
    Workout(
        date: Date(),
        exercises: [
            ExerciseLog(
                exercise: Exercise(name: "Incline Bench Press"),
                sets: [
                    WorkoutSet(reps: 8, weight: 60),
                    WorkoutSet(reps: 8, weight: 60)
                ]
            )
        ],
        completed: false
    )
}
