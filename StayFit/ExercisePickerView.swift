import SwiftUI

struct ExercisePickerView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var selectedGroup: MuscleGroup? = nil
    @State private var catalog: [ExerciseCatalogEntry] = []

    // Chip list: “All” + available groups in this catalog
    private var chipGroups: [MuscleGroup] {
        let all = Set(catalog.flatMap { groups(for: $0) })
        // Fixed order for consistency
        let order: [MuscleGroup] = [.Chest, .Back, .Shoulders, .Arms, .Legs, .Core, .Other]
        return order.filter(all.contains)
    }

    // Filtered results: by search text + selected broad group
    private var filtered: [ExerciseCatalogEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return catalog.filter { e in
            let nameHit = q.isEmpty || e.name.lowercased().contains(q) ||
                         (e.aliases ?? []).joined(separator: " ").lowercased().contains(q)
            let groupHit = (selectedGroup == nil) || groups(for: e).contains(selectedGroup!)
            return nameHit && groupHit
        }
    }

    var onSelect: (Exercise) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search
                HStack {
                    TextField("Search exercises", text: $query)
                        .textFieldStyle(.roundedBorder)
                }
                .padding([.horizontal, .top])

                // Muscle-group chip bar (broad groups)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // All chip
                        Chip(text: "All", isSelected: selectedGroup == nil) { selectedGroup = nil }
                        ForEach(chipGroups, id: \.self) { g in
                            Chip(text: g.rawValue, isSelected: selectedGroup == g) { selectedGroup = g }
                        }
                    }
                    .padding(.horizontal).padding(.vertical, 8)
                }

                // List
                List {
                    ForEach(filtered) { e in
                        Button {
                            let ex = store.addExercise(from: e)   // uses your DataStore helper
                            onSelect(ex)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(e.name).font(.headline)
                                // Show equipment + broad groups only (simple for users)
                                let subtitle = ([e.equipment ?? ""] + groups(for: e).map { $0.rawValue })
                                    .filter { !$0.isEmpty }
                                    .joined(separator: " • ")
                                Text(subtitle)
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Add Exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                catalog = CatalogLoader.load()
                store.preloadCatalogIfNeeded()   // optional seeding of your master list
            }
        }
    }
}
