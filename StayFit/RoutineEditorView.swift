import SwiftUI

struct RoutineEditorView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    @State var template: WorkoutTemplate
    @State private var showPicker = false
    @State private var editingName = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Fixed header with name field
                VStack(spacing: 12) {
                    TextField("Routine Name", text: $editingName)
                        .font(.system(size: 17))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                .padding(.top, 16)
                .background(Color(.systemBackground))
                
                // Scrollable exercise list
                ScrollView {
                    VStack(spacing: 12) {
                        if template.exercises.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "dumbbell")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.secondary)
                                Text("No exercises yet")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Text("Tap the button below to add exercises")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 60)
                            .padding(.horizontal)
                        } else {
                            ForEach(template.exercises.indices, id: \.self) { i in
                                ExerciseTemplateCard(
                                    exerciseTemplate: $template.exercises[i],
                                    index: i,
                                    onDelete: { removeExercise(at: i) }
                                )
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, 80) // Space for floating button
                }
            }
            .navigationTitle("Edit Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(editingName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { editingName = template.name }
            .overlay(alignment: .bottom) {
                // Floating Add button
                Button {
                    showPicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Add from Catalog")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerView { ex in
                    let defaultWeight: Double = 22.68 // 50 lbs
                    let newTemplate = ExerciseTemplate(
                        name: ex.name,
                        sets: [
                            WorkoutSet(reps: 10, weight: defaultWeight, kind: .work),
                            WorkoutSet(reps: 10, weight: defaultWeight, kind: .work),
                            WorkoutSet(reps: 10, weight: defaultWeight, kind: .work)
                        ]
                    )
                    template.exercises.append(newTemplate)
                }
                .environmentObject(store)
            }
        }
    }

    private func save() {
        template.name = editingName.trimmingCharacters(in: .whitespaces)
        store.saveTemplate(template)
        dismiss()
    }
    
    private func removeExercise(at index: Int) {
        withAnimation {
            template.exercises.remove(at: index)
        }
    }
}

// MARK: - Exercise Template Card
struct ExerciseTemplateCard: View {
    @Binding var exerciseTemplate: ExerciseTemplate
    @EnvironmentObject var settings: SettingsStore
    let index: Int
    let onDelete: () -> Void
    
    @State private var showDetail = false

    private var entry: ExerciseCatalogEntry? {
        CatalogLookup.shared.entry(forExerciseName: exerciseTemplate.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with exercise name
            HStack(spacing: 10) {
                Text("\(index + 1)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(.blue))
                
                Button {
                    showDetail = true
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exerciseTemplate.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                        
                        if let entry = entry {
                            let groupNames = groups(for: entry).map(\.rawValue)
                            let subtitle = ([entry.equipment ?? ""] + groupNames)
                                .filter { !$0.isEmpty }
                                .joined(separator: " • ")
                            Text(subtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button {
                    addSet()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(.blue.opacity(0.1)))
                }
                
                Menu {
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete Exercise", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color(.systemGray5)))
                }
            }
            
            // Sets list with native swipe-to-delete
            ForEach(exerciseTemplate.sets.indices, id: \.self) { setIndex in
                SetConfigurationRow(
                    set: $exerciseTemplate.sets[setIndex],
                    setNumber: setIndex + 1
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if exerciseTemplate.sets.count > 1 {
                        Button(role: .destructive) {
                            withAnimation {
                                _ = exerciseTemplate.sets.remove(at: setIndex)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .listRowInsets(EdgeInsets())
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .sheet(isPresented: $showDetail) {
            ExerciseDetailView(exerciseName: exerciseTemplate.name)
        }
    }
    
    private func addSet() {
        let lastSet = exerciseTemplate.sets.last
        let newSet = WorkoutSet(
            reps: lastSet?.reps ?? 10,
            weight: lastSet?.weight ?? 22.68,
            kind: .work,
            secondsRest: settings.defaultRestSeconds
        )
        withAnimation {
            exerciseTemplate.sets.append(newSet)
        }
    }
}

// MARK: - Set Configuration Row (Simplified)
struct SetConfigurationRow: View {
    @Binding var set: WorkoutSet
    @EnvironmentObject var settings: SettingsStore
    let setNumber: Int
    
    var body: some View {
        HStack(spacing: 10) {
            // Set number/type button
            Button {
                cycleSetType()
            } label: {
                Text(setTypeDisplay)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(setTypeColor)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(setTypeBackgroundColor)
                    )
            }
            .buttonStyle(.plain)
            
            // Weight input
            VStack(spacing: 2) {
                Text(settings.unit.label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                
                TextField("", value: Binding(
                    get: { settings.toDisplayWeight(kg: set.weight) },
                    set: { newVal in set.weight = settings.fromDisplayWeight(newVal) }
                ), format: .number.precision(.fractionLength(0)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 50)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemBackground))
                )
            }
            
            Text("×")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            
            // Reps input
            VStack(spacing: 2) {
                Text(" ")
                    .font(.system(size: 9, weight: .medium))
                
                TextField("", value: $set.reps, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 40)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemBackground))
                    )
            }
            
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
        )
    }
    
    private var setTypeDisplay: String {
        switch set.kind {
        case .work: return "\(setNumber)"
        case .warmup: return "W"
        case .dropset: return "D"
        }
    }
    
    private var setTypeColor: Color {
        switch set.kind {
        case .work: return .blue
        case .warmup: return .orange
        case .dropset: return .purple
        }
    }
    
    private var setTypeBackgroundColor: Color {
        switch set.kind {
        case .work: return .blue.opacity(0.15)
        case .warmup: return .orange.opacity(0.15)
        case .dropset: return .purple.opacity(0.15)
        }
    }
    
    private func cycleSetType() {
        switch set.kind {
        case .work: set.kind = .warmup
        case .warmup: set.kind = .dropset
        case .dropset: set.kind = .work
        }
    }
}

// MARK: - Color Extension
extension Color {
    static func lerp(from: Color, to: Color, progress: Double) -> Color {
        let progress = max(0, min(1, progress))
        return Color(
            .sRGB,
            red: from.components.red + (to.components.red - from.components.red) * progress,
            green: from.components.green + (to.components.green - from.components.green) * progress,
            blue: from.components.blue + (to.components.blue - from.components.blue) * progress
        )
    }
    
    private var components: (red: Double, green: Double, blue: Double) {
        let uiColor = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue))
    }
}
