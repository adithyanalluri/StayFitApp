import SwiftUI

struct RoutinesView: View {
    @EnvironmentObject var store: DataStore
    @State private var showingNew = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // New button
                    Button {
                        showingNew = true
                    } label: {
                        Card {
                            HStack {
                                Image(systemName: "plus.circle.fill").font(.title3)
                                Text("New Routine")
                                Spacer()
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    // Cards
                    ForEach(store.templates) { t in
                        NavigationLink {
                            RoutineEditorView(template: t)
                        } label: {
                            Card {
                                CardHeader(t.name) {
                                    Text("\(t.exercises.count) exercises")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.bottom, 6)

                                HStack(spacing: 8) {
                                    Button {
                                        let copy = WorkoutTemplate(name: t.name + " Copy", exercises: t.exercises)
                                        store.saveTemplate(copy)
                                    } label: {
                                        Label("Duplicate", systemImage: "plus.square.on.square")
                                    }
                                    .buttonStyle(.bordered)

                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) { delete(template: t) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Routines")
            .sheet(isPresented: $showingNew) {
                RoutineEditorView(template: WorkoutTemplate(name: "New Routine", exercises: []))
            }
        }
    }

    private func delete(template: WorkoutTemplate) {
        if let idx = store.templates.firstIndex(where: { $0.id == template.id }) {
            store.templates.remove(at: idx)
        }
    }
}
