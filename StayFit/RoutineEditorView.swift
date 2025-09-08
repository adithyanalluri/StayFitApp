import SwiftUI

struct RoutineEditorView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss

    @State var template: WorkoutTemplate
    @State private var showPicker = false
    @State private var editingName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Routine Name") {
                    TextField("e.g. Push Day A", text: $editingName)
                        .textInputAutocapitalization(.words)
                }

                Section("Exercises") {
                    // Always return a List here (avoids generic V inference issue)
                    List {
                        if template.exercises.isEmpty {
                            Text("No exercises yet. Tap **Add from Catalog** below.")
                                .foregroundStyle(.secondary)
                        } else {
                            // Work with names so it doesn’t matter whether items are Exercise or ExerciseTemplate
                            ForEach(template.exercises.indices, id: \.self) { i in
                                let name = template.exercises[i].name
                                RoutineRow(name: name, index: i)
                            }
                            .onDelete { idx in
                                template.exercises.remove(atOffsets: idx)
                            }
                            .onMove { from, to in
                                template.exercises.move(fromOffsets: from, toOffset: to)
                            }
                        }
                    }

                    Button {
                        showPicker = true
                    } label: {
                        Label("Add from Catalog", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .sheet(isPresented: $showPicker) {
                        ExercisePickerView { ex in
                            // Convert picked Exercise -> ExerciseTemplate
                            // Adjust this initializer if your ExerciseTemplate differs.
                            #if compiler(>=5.9)
                            template.exercises.append(ExerciseTemplate(name: ex.name))
                            #else
                            template.exercises.append(ExerciseTemplate(name: ex.name))
                            #endif
                        }
                        .environmentObject(store)
                    }
                }
            }
            .navigationTitle("Edit Routine")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(editingName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { editingName = template.name }
        }
    }

    private func save() {
        template.name = editingName.trimmingCharacters(in: .whitespaces)
        store.saveTemplate(template)
        dismiss()
    }
}

// Row now only needs a name string
private struct RoutineRow: View {
    let name: String
    let index: Int

    var body: some View {
        HStack {
            Text("\(index + 1).")
                .frame(width: 28, alignment: .trailing)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.headline)

                if let entry = CatalogLookup.shared.entry(forExerciseName: name) {
                    let subtitle = ([entry.equipment ?? ""] + Array(groups(for: entry)).map(\.rawValue))
                        .filter { !$0.isEmpty }
                        .joined(separator: " • ")
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
        }
    }
}
