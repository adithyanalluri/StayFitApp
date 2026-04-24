import Foundation

struct PRBaseline {
    let heaviestWeight: Double
    let mostReps: Int
    let bestOneRM: Double
}

enum PRAchievement: String, CaseIterable, Comparable, Equatable {
    case heaviestWeight = "Heaviest Weight"
    case mostReps = "Most Reps"
    case bestOneRM = "Best 1RM"

    static func < (lhs: PRAchievement, rhs: PRAchievement) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

func oneRepMax(weight: Double, reps: Int) -> Double {
    weight * Double(reps) * 0.0333 + weight
}

func achievements(forSets sets: [WorkoutSet], baseline: PRBaseline) -> [PRAchievement] {
    var achieved = Set<PRAchievement>()
    for s in sets {
        if s.weight > baseline.heaviestWeight { achieved.insert(.heaviestWeight) }
        if s.reps > baseline.mostReps { achieved.insert(.mostReps) }
        if oneRepMax(weight: s.weight, reps: s.reps) > baseline.bestOneRM { achieved.insert(.bestOneRM) }
    }
    return achieved.sorted()
}
