import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var timer: TimerManager

    var body: some View {
        TabView {
            // MARK: Log tab
            NavigationStack {
                List {
                    Section {
                        NavigationLink {
                            StartWorkoutView(currentWorkout: quickStartWorkout())
                                .environmentObject(store)
                                .environmentObject(settings)
                                .environmentObject(timer)
                        } label: {
                            Label("Quick Start Workout", systemImage: "play.circle.fill")
                                .font(.headline)
                        }
                    }

                    // Start from template (if any)
                    if !store.templates.isEmpty {
                        Section("Start from Template") {
                            ForEach(store.templates) { tmpl in
                                NavigationLink {
                                    let w = store.instantiateWorkout(from: tmpl)
                                    StartWorkoutView(currentWorkout: w)
                                        .environmentObject(store)
                                        .environmentObject(settings)
                                        .environmentObject(timer)
                                } label: {
                                    HStack {
                                        Text(tmpl.name)
                                        Spacer()
                                        Text("\(tmpl.exercises.count) exercises")
                                            .foregroundStyle(.secondary)
                                            .font(.subheadline)
                                    }
                                }
                            }
                        }
                    }

                    // Recent workouts
                    if !store.workouts.isEmpty {
                        Section("Recent Workouts") {
                            ForEach(store.workouts.prefix(5)) { w in
                                NavigationLink {
                                    // If you have a detail screen, replace with it:
                                    WorkoutDetailView(workout: w)
                                        .environmentObject(store)
                                        .environmentObject(settings)
                                } label: {
                                    HStack {
                                        Text(w.date, style: .date)
                                        Spacer()
                                        if w.completed {
                                            Label("Saved", systemImage: "checkmark.seal.fill")
                                                .labelStyle(.iconOnly)
                                                .foregroundStyle(.green)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Log")
            }
            .tabItem {
                Label("Log", systemImage: "figure.strengthtraining.traditional")
            }

            // MARK: Routines tab
            NavigationStack {
                RoutinesView()
            }
            .tabItem {
                Label("Routines", systemImage: "list.bullet.rectangle")
            }

            // MARK: History tab
            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }

            // MARK: Settings tab
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }

    // MARK: - Helpers

    /// Creates a minimal, empty workout you can pass to StartWorkoutView.
    private func quickStartWorkout() -> Workout {
        Workout(
            date: Date(),
            exercises: [],
            completed: false
        )
    }
}

// MARK: - Preview
#Preview {
    let store = DataStore()
    let settings = SettingsStore()
    HomeView()
        .environmentObject(store)
        .environmentObject(settings)
}
