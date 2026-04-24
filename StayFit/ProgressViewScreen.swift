import SwiftUI
import Charts

struct ExerciseProgressView: View {
    let exerciseName: String
    
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var settings: SettingsStore
    
    @State private var selectedMetric: Metric = .weight
    
    enum Metric: String, CaseIterable {
        case weight = "Weight"
        case volume = "Volume"
        case reps = "Reps"
        case oneRM = "Est. 1RM"
    }
    
    private var exerciseHistory: [(Date, [WorkoutSet])] {
        store.workouts
            .filter { $0.completed }
            .compactMap { workout -> (Date, [WorkoutSet])? in
                guard let log = workout.exercises.first(where: { $0.exercise.name == exerciseName }) else {
                    return nil
                }
                return (workout.date, log.sets)
            }
            .sorted(by: { $0.0 < $1.0 })
    }
    
    private var pr: ExercisePR? {
        store.prs[exerciseName]
    }
    
    private var chartData: [(Date, Double)] {
        exerciseHistory.map { date, sets in
            let value: Double
            switch selectedMetric {
            case .weight:
                value = sets.max(by: { $0.weight < $1.weight })?.weight ?? 0
            case .volume:
                value = sets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
            case .reps:
                value = Double(sets.max(by: { $0.reps < $1.reps })?.reps ?? 0)
            case .oneRM:
                value = sets.map { epley1RM(weight: $0.weight, reps: $0.reps) }.max() ?? 0
            }
            return (date, value)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // PRs Card
                if let pr = pr {
                    PRSummaryCard(pr: pr, settings: settings)
                }
                
                // Metric selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Metric.allCases, id: \.self) { metric in
                            Button {
                                selectedMetric = metric
                            } label: {
                                Text(metric.rawValue)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(selectedMetric == metric ? .white : .primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(selectedMetric == metric ? Color.blue : Color(.systemGray5))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Progress chart
                ProgressChartCard(
                    data: chartData,
                    metric: selectedMetric,
                    settings: settings
                )
                
                // Recent workouts for this exercise
                RecentWorkoutsSection(
                    exerciseName: exerciseName,
                    history: exerciseHistory.reversed(),
                    settings: settings
                )
            }
            .padding()
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func epley1RM(weight: Double, reps: Int) -> Double {
        guard reps > 0 else { return 0 }
        return weight * (1.0 + Double(reps) / 30.0)
    }
}

// MARK: - PR Summary Card
struct PRSummaryCard: View {
    let pr: ExercisePR
    let settings: SettingsStore
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Personal Records")
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                PRBox(
                    title: "Max Weight",
                    value: "\(Int(settings.toDisplayWeight(kg: pr.heaviestWeight)))",
                    unit: settings.unit.label,
                    color: .blue
                )
                
                PRBox(
                    title: "Most Reps",
                    value: "\(pr.mostReps)",
                    unit: "reps",
                    color: .green
                )
                
                PRBox(
                    title: "Est. 1RM",
                    value: "\(Int(settings.toDisplayWeight(kg: pr.bestOneRM)))",
                    unit: settings.unit.label,
                    color: .orange
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

struct PRBox: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 20))
                .foregroundStyle(color)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                Text(unit)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Progress Chart Card
struct ProgressChartCard: View {
    let data: [(Date, Double)]
    let metric: ExerciseProgressView.Metric
    let settings: SettingsStore
    
    private var yAxisLabel: String {
        switch metric {
        case .weight:
            return "Weight (\(settings.unit.label))"
        case .volume:
            return "Volume (\(settings.unit.label))"
        case .reps:
            return "Reps"
        case .oneRM:
            return "Est. 1RM (\(settings.unit.label))"
        }
    }
    
    private var displayData: [(Date, Double)] {
        data.map { date, value in
            let displayValue: Double
            switch metric {
            case .weight, .volume, .oneRM:
                displayValue = settings.toDisplayWeight(kg: value)
            case .reps:
                displayValue = value
            }
            return (date, displayValue)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress Chart")
                .font(.system(size: 16, weight: .semibold))
            
            if displayData.isEmpty {
                Text("No data available")
                    .foregroundStyle(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else if #available(iOS 16.0, *) {
                Chart {
                    ForEach(displayData, id: \.0) { date, value in
                        LineMark(
                            x: .value("Date", date),
                            y: .value(metric.rawValue, value)
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)
                        .symbol(Circle().strokeBorder(lineWidth: 2))
                        
                        PointMark(
                            x: .value("Date", date),
                            y: .value(metric.rawValue, value)
                        )
                        .foregroundStyle(.blue)
                    }
                }
                .frame(height: 250)
                .chartYAxisLabel(yAxisLabel)
            } else {
                Text("Charts available in iOS 16+")
                    .foregroundStyle(.secondary)
                    .frame(height: 250)
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

// MARK: - Recent Workouts Section
struct RecentWorkoutsSection: View {
    let exerciseName: String
    let history: [(Date, [WorkoutSet])]
    let settings: SettingsStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Workouts")
                .font(.system(size: 16, weight: .semibold))
            
            if history.isEmpty {
                Text("No workout history yet")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(history.prefix(10), id: \.0) { date, sets in
                        WorkoutSessionCard(date: date, sets: sets, settings: settings)
                    }
                }
            }
        }
    }
}

struct WorkoutSessionCard: View {
    let date: Date
    let sets: [WorkoutSet]
    let settings: SettingsStore
    
    @State private var isExpanded = false
    
    private var bestSet: WorkoutSet? {
        sets.max(by: { ($0.weight * Double($0.reps)) < ($1.weight * Double($1.reps)) })
    }
    
    private var totalVolume: Double {
        sets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 15, weight: .semibold))
                        
                        if let best = bestSet {
                            Text("Best: \(Int(settings.toDisplayWeight(kg: best.weight))) \(settings.unit.label) × \(best.reps)")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(sets.count) sets")
                            .font(.system(size: 13, weight: .medium))
                        Text("\(Int(settings.toDisplayWeight(kg: totalVolume))) \(settings.unit.label)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                Divider()
                
                VStack(spacing: 6) {
                    ForEach(sets.indices, id: \.self) { index in
                        HStack {
                            Text("\(index + 1)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            
                            Text("\(Int(settings.toDisplayWeight(kg: sets[index].weight))) \(settings.unit.label) × \(sets[index].reps)")
                                .font(.system(size: 14))
                            
                            Spacer()
                            
                            if sets[index].kind == .warmup {
                                Text("W")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(.orange.opacity(0.15))
                                    )
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
    }
}
