import Foundation
import SwiftUI

// Matches the JSON
struct ExerciseCatalogEntry: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var aliases: [String]?
    var equipment: String?
    var mechanics: String?
    var force: String?
    var primary_muscles: [String]
    var secondary_muscles: [String]?
    var stabilizers: [String]?
    var media: String?          // URL or asset name (for future animations)
    var instructions: [String]?
}

enum CatalogLoader {
    static func load() -> [ExerciseCatalogEntry] {
        guard let url = Bundle.main.url(forResource: "ExerciseCatalog", withExtension: "json") else {
            print("⚠️ ExerciseCatalog.json not found in bundle")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([ExerciseCatalogEntry].self, from: data)
        } catch {
            print("⚠️ Catalog decode error:", error)
            return []
        }
    }
}

// MARK: - DataStore helpers (no model changes required)
extension DataStore {
    /// Ensure your master list contains common exercises from the bundled catalog.
    /// Uses your existing `addExerciseToMaster(name:)` to avoid duplicates.
    func preloadCatalogIfNeeded() {
        let entries = CatalogLoader.load()
        for e in entries {
            _ = addExerciseToMaster(name: e.name)
        }
        // No calls to `masterExercises` or `saveAll` required.
    }

    /// Add a specific catalog entry to the master list and return the Exercise.
    func addExercise(from entry: ExerciseCatalogEntry) -> Exercise {
        return addExerciseToMaster(name: entry.name)
    }
}
