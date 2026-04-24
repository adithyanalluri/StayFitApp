import SwiftUI
import Combine

struct WorkoutDetailView: View {
    let workout: Workout
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var store: DataStore

    @State private var notesDraft: String = ""
    @State private var notesCancellable: AnyCancellable?
    @State private var saveStatus: String? = nil
    @State private var saveStatusTask: Task<Void, Never>? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Summary card
                Card {
                    CardHeader(NSLocalizedString("Summary", comment: "summary header")) { EmptyView() }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(workout.date.formatted(date: .abbreviated, time: .shortened))
                        Text(exerciseCountString)
                        Text(totalSetsString)
                            .foregroundStyle(.secondary)
                        if let rating = workout.rating {
                            HStack(spacing: 4) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: rating >= star ? "star.fill" : "star")
                                        .foregroundStyle(rating >= star ? .yellow : .secondary)
                                }
                                Text("\(rating)/5")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }.font(.subheadline)
                }

                // Exercise cards
                ForEach(workout.exercises) { log in
                    Card {
                        CardHeader(log.exercise.name) { EmptyView() }
                            .padding(.bottom, 6)

                        // headers
                        HStack {
                            Text(LocalizedStringKey("Set")).frame(minWidth: 28, alignment: .leading)
                            Text(weightHeader).frame(minWidth: 60, alignment: .leading)
                            Text(LocalizedStringKey("Reps")).frame(minWidth: 50, alignment: .leading)
                            Spacer()
                            Text(LocalizedStringKey("Type")).frame(minWidth: 44, alignment: .leading)
                        }
                        .foregroundStyle(.secondary)
                        .font(.subheadline)

                        if log.sets.isEmpty {
                            Text(NSLocalizedString("No sets logged.", comment: "empty exercise sets"))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                        }

                        ForEach(Array(log.sets.enumerated()), id: \.1.id) { idx, s in
                            HStack {
                                Text("\(idx+1)").frame(minWidth: 28, alignment: .leading)
                                Text(formattedWeight(s.weight))
                                    .frame(minWidth: 60, alignment: .leading)
                                Text("\(s.reps)").frame(minWidth: 50, alignment: .leading)
                                Spacer()
                                Text(s.kind == .warmup ? NSLocalizedString("WU", comment: "Warmup abbreviation") : NSLocalizedString("Work", comment: "Working set label"))
                                    .foregroundStyle(.secondary)
                                    .frame(minWidth: 44, alignment: .leading)
                            }
                        }

                        // PR Banner Logic:
                        // Check if this workout contains a new PR for this exercise (weight, reps, or 1RM)
                        if let prInfo = newPR(for: log) {
                            Divider().padding(.vertical, 8)
                            HStack(spacing: 6) {
                                Image(systemName: "trophy.fill")
                                    .foregroundStyle(.yellow)
                                Text(LocalizedStringKey("New PR!"))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.yellow)
                                Text(prInfo)
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                                Spacer()
                            }
                            .padding(8)
                            .background(Color.yellow.opacity(0.15))
                            .cornerRadius(8)
                        }
                    }
                }

                // Workout Notes card
                Card {
                    CardHeader(NSLocalizedString("Workout Notes", comment: "workout notes header")) { EmptyView() }
                    if workout.completed {
                        // Read-only notes
                        if !workout.notes.isEmpty {
                            Text(workout.notes)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 4)
                        } else {
                            Text(NSLocalizedString("No notes for this workout.", comment: "empty notes"))
                                .foregroundStyle(.secondary)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 4)
                        }
                    } else {
                        // Editable notes
                        TextEditor(text: $notesDraft)
                            .font(.body)
                            .frame(minHeight: 80)
                            .padding(4)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .onReceive(Just(notesDraft)
                                .debounce(for: .milliseconds(700), scheduler: RunLoop.main)) { newValue in
                                var updated = workout
                                updated.notes = newValue
                                store.saveWorkout(updated)

                                saveStatus = NSLocalizedString("Saved", comment: "notes saved status")
                                saveStatusTask?.cancel()
                                saveStatusTask = Task {
                                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                                    if !Task.isCancelled {
                                        await MainActor.run {
                                            saveStatus = nil
                                        }
                                    }
                                }
                            }
                        if let saveStatus {
                            Text(saveStatus)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .transition(.opacity)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(LocalizedStringKey("Workout"))
        .onAppear {
            self.notesDraft = workout.notes
        }
    }

    private var exerciseCountString: String {
        let count = workout.exercises.count
        if count == 1 {
            return String(format: NSLocalizedString("%d exercise", comment: "one exercise"), count)
        } else {
            return String(format: NSLocalizedString("%d exercises", comment: "multiple exercises"), count)
        }
    }

    private var totalSetsString: String {
        let count = totalSets
        if count == 1 {
            return String(format: NSLocalizedString("%d total set", comment: "one set"), count)
        } else {
            return String(format: NSLocalizedString("%d total sets", comment: "multiple sets"), count)
        }
    }

    private var weightHeader: String {
        let unitLabel = settings.unit.label
        return String(format: NSLocalizedString("%@", comment: "weight unit header"), unitLabel)
    }

    private func formattedWeight(_ kg: Double) -> String {
        let value = settings.toDisplayWeight(kg: kg)
        let rounded = (value * 10).rounded() / 10
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = rounded.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1
        let number = NSNumber(value: rounded)
        let valueString = formatter.string(from: number) ?? String(format: "%.1f", rounded)
        return "\(valueString) \(settings.unit.label)"
    }

    private var totalSets: Int {
        workout.exercises.reduce(0) { $0 + $1.sets.count }
    }

    private func newPR(for log: ExerciseLog) -> String? {
        guard let baseline = store.prs[log.exercise.name] else { return nil }
        let prBaseline = PRBaseline(heaviestWeight: baseline.heaviestWeight, mostReps: baseline.mostReps, bestOneRM: baseline.bestOneRM)
        let achieved = achievements(forSets: log.sets, baseline: prBaseline)
        guard !achieved.isEmpty else { return nil }
        return achieved.map { $0.rawValue }.joined(separator: ", ")
    }
}
