import Foundation

enum MuscleGroup: String, CaseIterable, Identifiable, Hashable {
    case Chest, Back, Shoulders, Arms, Legs, Core, Other
    var id: String { rawValue }
}

// Map detailed muscle strings → a broad MuscleGroup
func groupForMuscle(_ name: String) -> MuscleGroup {
    let s = name.lowercased()

    // Chest
    if s.contains("pector") || s.contains("chest") { return .Chest }

    // Back (lats, traps, rhomboids, erector spinae, “mid/upper/lower back”)
    if s.contains("lat") || s.contains("trap") || s.contains("rhomboid") ||
       s.contains("erector") || s.contains("mid back") || s.contains("upper back") ||
       s.contains("lower back") || s.contains("back") { return .Back }

    // Shoulders (delts)
    if s.contains("deltoid") || s.contains("shoulder") { return .Shoulders }

    // Arms (biceps, triceps, forearms, brachialis, brachioradialis)
    if s.contains("bicep") || s.contains("tricep") || s.contains("forearm") ||
       s.contains("brachialis") || s.contains("brachioradialis") { return .Arms }

    // Legs (quads, hams, glutes, adductors, calves, soleus)
    if s.contains("quad") || s.contains("hamstring") || s.contains("glute") ||
       s.contains("adductor") || s.contains("calf") || s.contains("gastrocnemius") ||
       s.contains("soleus") || s.contains("leg") { return .Legs }

    // Core (abs, obliques, core, transverse, pelvic floor)
    if s.contains("core") || s.contains("ab ") || s.contains("abs") ||
       s.contains("rectus") || s.contains("oblique") || s.contains("transvers") {
        return .Core
    }

    return .Other
}

// Compute the broad groups for a catalog entry (primary + secondary)
func groups(for entry: ExerciseCatalogEntry) -> Set<MuscleGroup> {
    var set = Set<MuscleGroup>()
    for m in entry.primary_muscles { set.insert(groupForMuscle(m)) }
    for m in entry.secondary_muscles ?? [] { set.insert(groupForMuscle(m)) }
    // Normalize combined “legs” preference (hamstrings+glutes etc. already map to .Legs)
    if set.isEmpty { set.insert(.Other) }
    return set
}

