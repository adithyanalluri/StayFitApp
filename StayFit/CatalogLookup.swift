import Foundation

@MainActor
final class CatalogLookup {
    static let shared = CatalogLookup()
    private(set) var entries: [ExerciseCatalogEntry] = []
    private var byName: [String: ExerciseCatalogEntry] = [:]

    private init() {
        reloadIfNeeded()
    }

    func reloadIfNeeded() {
        if entries.isEmpty {
            entries = CatalogLoader.load()
            byName.removeAll()
            for e in entries {
                byName[e.name.lowercased()] = e
                for a in (e.aliases ?? []) {
                    byName[a.lowercased()] = e
                }
            }
        }
    }

    /// Return full catalog entry for a display name (or alias)
    func entry(forExerciseName name: String) -> ExerciseCatalogEntry? {
        reloadIfNeeded()
        return byName[name.lowercased()]
    }

    /// Convenience accessors used by UI
    func primaryMuscles(for name: String) -> [String] {
        entry(forExerciseName: name)?.primary_muscles ?? []
    }
    func secondaryMuscles(for name: String) -> [String] {
        entry(forExerciseName: name)?.secondary_muscles ?? []
    }
    func stabilizers(for name: String) -> [String] {
        entry(forExerciseName: name)?.stabilizers ?? []
    }
    func equipment(for name: String) -> String? {
        entry(forExerciseName: name)?.equipment
    }
    func instructions(for name: String) -> [String] {
        entry(forExerciseName: name)?.instructions ?? []
    }
    func media(for name: String) -> String? {
        entry(forExerciseName: name)?.media
    }
}
