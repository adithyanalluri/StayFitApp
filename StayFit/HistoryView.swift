import SwiftUI
import Charts

struct HistoryView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var settings: SettingsStore
    
    @State private var selectedTimeframe: Timeframe = .month
    @State private var showStats = true
    
    enum Timeframe: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case threeMonths = "3 Months"
        case year = "Year"
        case all = "All Time"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            case .year: return 365
            case .all: return 10000
            }
        }
    }
    
    private var filteredWorkouts: [Workout] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -selectedTimeframe.days, to: Date()) ?? Date()
        return store.workouts
            .filter { $0.completed && $0.date >= cutoffDate }
            .sorted(by: { $0.date > $1.date })
    }
    
    private var stats: WorkoutStats {
        calculateStats(for: filteredWorkouts)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Timeframe selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Timeframe.allCases, id: \.self) { timeframe in
                                Button {
                                    selectedTimeframe = timeframe
                                } label: {
                                    Text(timeframe.rawValue)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(selectedTimeframe == timeframe ? .white : .primary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(selectedTimeframe == timeframe ? Color.blue : Color(.systemGray5))
                                        )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    if filteredWorkouts.isEmpty {
                        emptyState
                    } else {
                        // Stats overview
                        StatsOverviewCard(stats: stats, settings: settings)
                        
                        // Volume chart
                        VolumeChartCard(workouts: filteredWorkouts, settings: settings)
                        
                        // Personal Records
                        PersonalRecordsCard(settings: settings)
                        
                        // Workout list
                        WorkoutListSection(workouts: filteredWorkouts, settings: settings)
                    }
                }
                .padding()
            }
            .navigationTitle("History")
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Workouts Yet")
                .font(.title2.bold())
            
            Text("Complete your first workout to see your progress here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 100)
    }
    
    private func calculateStats(for workouts: [Workout]) -> WorkoutStats {
        let totalWorkouts = workouts.count
        let totalExercises = workouts.reduce(0) { $0 + $1.exercises.count }
        let totalSets = workouts.reduce(0) { total, workout in
            total + workout.exercises.reduce(0) { $0 + $1.sets.count }
        }
        let totalVolumeKg = workouts.reduce(0.0) { total, workout in
            total + workout.exercises.reduce(0.0) { exerciseTotal, log in
                exerciseTotal + log.sets.reduce(0.0) { setTotal, set in
                    setTotal + (set.weight * Double(set.reps))
                }
            }
        }
        
        return WorkoutStats(
            totalWorkouts: totalWorkouts,
            totalExercises: totalExercises,
            totalSets: totalSets,
            totalVolumeKg: totalVolumeKg
        )
    }
}

// MARK: - Stats Overview Card
struct StatsOverviewCard: View {
    let stats: WorkoutStats
    let settings: SettingsStore
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                StatBox(
                    title: "Workouts",
                    value: "\(stats.totalWorkouts)",
                    icon: "figure.strengthtraining.traditional",
                    color: .blue
                )
                
                StatBox(
                    title: "Exercises",
                    value: "\(stats.totalExercises)",
                    icon: "list.bullet",
                    color: .green
                )
            }
            
            HStack(spacing: 16) {
                StatBox(
                    title: "Total Sets",
                    value: "\(stats.totalSets)",
                    icon: "number",
                    color: .orange
                )
                
                StatBox(
                    title: "Volume",
                    value: "\(Int(settings.toDisplayWeight(kg: stats.totalVolumeKg)))",
                    subtitle: settings.unit.label,
                    icon: "scalemass",
                    color: .purple
                )
            }
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    var subtitle: String?
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                Spacer()
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Volume Chart Card
struct VolumeChartCard: View {
    let workouts: [Workout]
    let settings: SettingsStore
    
    private var chartData: [(Date, Double)] {
        workouts.map { workout in
            let volume = workout.exercises.reduce(0.0) { total, log in
                total + log.sets.reduce(0.0) { $0 + (settings.toDisplayWeight(kg: $1.weight) * Double($1.reps)) }
            }
            return (workout.date, volume)
        }
        .sorted(by: { $0.0 < $1.0 })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Volume Over Time")
                .font(.system(size: 18, weight: .semibold))
            
            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(chartData, id: \.0) { date, volume in
                        LineMark(
                            x: .value("Date", date),
                            y: .value("Volume", volume)
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Date", date),
                            y: .value("Volume", volume)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .blue.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
                .frame(height: 200)
                .chartYAxisLabel("Volume (\(settings.unit.label))")
            } else {
                // Fallback for iOS 15
                Text("Charts available in iOS 16+")
                    .foregroundStyle(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Personal Records Card
struct PersonalRecordsCard: View {
    @EnvironmentObject var store: DataStore
    let settings: SettingsStore
    
    private var topPRs: [(String, ExercisePR)] {
        Array(store.prs.sorted(by: { $0.value.bestOneRM > $1.value.bestOneRM }).prefix(5))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Personal Records")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
                
                NavigationLink {
                    AllPersonalRecordsView()
                } label: {
                    Text("See All")
                        .font(.system(size: 14))
                        .foregroundStyle(.blue)
                }
            }
            
            if topPRs.isEmpty {
                Text("Complete workouts to track your PRs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(topPRs, id: \.0) { exerciseName, pr in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exerciseName)
                                    .font(.system(size: 14, weight: .medium))
                                Text("1RM: \(Int(settings.toDisplayWeight(kg: pr.bestOneRM))) \(settings.unit.label)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(.orange)
                        }
                        .padding(.vertical, 4)
                        
                        if exerciseName != topPRs.last?.0 {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Workout List Section
struct WorkoutListSection: View {
    let workouts: [Workout]
    let settings: SettingsStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Workouts")
                .font(.system(size: 18, weight: .semibold))
            
            VStack(spacing: 12) {
                ForEach(workouts) { workout in
                    NavigationLink {
                        WorkoutDetailView(workout: workout)
                    } label: {
                        WorkoutRowCard(workout: workout, settings: settings)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct WorkoutRowCard: View {
    let workout: Workout
    let settings: SettingsStore
    
    private var totalVolume: Double {
        workout.exercises.reduce(0.0) { total, log in
            total + log.sets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(workout.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 16, weight: .semibold))
                
                HStack(spacing: 16) {
                    Label("\(workout.exercises.count) exercises", systemImage: "list.bullet")
                    Label("\(totalSets) sets", systemImage: "number")
                }
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                
                Text("\(Int(settings.toDisplayWeight(kg: totalVolume))) \(settings.unit.label) volume")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.blue)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var totalSets: Int {
        workout.exercises.reduce(0) { $0 + $1.sets.count }
    }
}

// MARK: - Supporting Models
struct WorkoutStats {
    let totalWorkouts: Int
    let totalExercises: Int
    let totalSets: Int
    let totalVolumeKg: Double
}

// MARK: - All PRs View
struct AllPersonalRecordsView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var settings: SettingsStore
    
    private var sortedPRs: [(String, ExercisePR)] {
        store.prs.sorted(by: { $0.key < $1.key })
    }
    
    var body: some View {
        List {
            ForEach(sortedPRs, id: \.0) { exerciseName, pr in
                NavigationLink {
                    ExerciseProgressView(exerciseName: exerciseName)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exerciseName)
                            .font(.system(size: 16, weight: .semibold))
                        
                        HStack(spacing: 16) {
                            Text("Max: \(Int(settings.toDisplayWeight(kg: pr.heaviestWeight))) \(settings.unit.label)")
                            Text("Reps: \(pr.mostReps)")
                            Text("1RM: \(Int(settings.toDisplayWeight(kg: pr.bestOneRM))) \(settings.unit.label)")
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Personal Records")
        .navigationBarTitleDisplayMode(.inline)
    }
}   
