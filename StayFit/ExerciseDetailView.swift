import SwiftUI

struct ExerciseDetailView: View {
    let exerciseName: String

    private var entry: ExerciseCatalogEntry? {
        CatalogLookup.shared.entry(forExerciseName: exerciseName)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Title
                Text(exerciseName)
                    .font(.system(size: 22, weight: .semibold))

                // Equipment + broad groups
                HStack(spacing: 8) {
                    if let eq = entry?.equipment, !eq.isEmpty {
                        Label(eq, systemImage: "gearshape")
                            .font(.subheadline)
                    }
                    let broad = entry.map { groups(for: $0) } ?? []
                    ForEach(Array(broad), id: \.self) { g in
                        Text(g.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Capsule().fill(Color.blue.opacity(0.15)))
                    }
                }
                .foregroundStyle(.secondary)

                // --- Place animation or image preview here later ---
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .frame(height: 180)
                    .overlay(Text("Animation placeholder").foregroundStyle(.secondary))

                // Detailed muscle lists (these stay in the backend & are shown here)
                if let primary = entry?.primary_muscles, !primary.isEmpty {
                    section("Primary Muscles", items: primary, highlight: true)
                }
                if let secondary = entry?.secondary_muscles, !secondary.isEmpty {
                    section("Secondary Muscles", items: secondary, highlight: false)
                }
                if let stabs = entry?.stabilizers, !stabs.isEmpty {
                    section("Stabilizers", items: stabs, highlight: false)
                }

                if let steps = entry?.instructions, !steps.isEmpty {
                    Text("Instructions")
                        .font(.headline)
                        .padding(.top, 6)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(i+1).").bold()
                                Text(s)
                            }
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func section(_ title: String, items: [String], highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Wrap(items: items) { text in
                Text(text)
                    .font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(
                        Capsule().fill(highlight ? Color.green.opacity(0.18) : Color.gray.opacity(0.15))
                    )
            }
        }
    }
}

// Simple wrap layout for chips
struct Wrap<ItemView: View>: View {
    let items: [String]
    let item: (String) -> ItemView
    init(items: [String], @ViewBuilder item: @escaping (String) -> ItemView) {
        self.items = items; self.item = item
    }
    var body: some View {
        var width: CGFloat = 0
        var height: CGFloat = 0
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(items, id: \.self) { str in
                    item(str)
                        .padding(4)
                        .alignmentGuide(.leading, computeValue: { d in
                            if (abs(width - d.width) > geo.size.width) {
                                width = 0
                                height -= d.height
                            }
                            let result = width
                            width -= d.width
                            return result
                        })
                        .alignmentGuide(.top, computeValue: { _ in
                            let result = height
                            return result
                        })
                }
            }
        }
        .frame(minHeight: 0)
        .frame(height: intrinsicHeight(forWidth: UIScreen.main.bounds.width - 32)) // crude but fine for chips
    }

    private func intrinsicHeight(forWidth _: CGFloat) -> CGFloat { 100 } // simple cap; chips will scroll if needed
}
