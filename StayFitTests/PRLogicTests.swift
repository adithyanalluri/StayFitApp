import XCTest
@testable import StayFit

final class PRLogicTests: XCTestCase {

    func testNoSetsYieldsNoAchievements() {
        let baseline = PRBaseline(heaviestWeight: 100, mostReps: 10, bestOneRM: 130)
        let result = achievements(forSets: [], baseline: baseline)
        XCTAssertTrue(result.isEmpty)
    }

    func testBeatingHeaviestWeightOnly() {
        let baseline = PRBaseline(heaviestWeight: 100, mostReps: 10, bestOneRM: 130)
        let sets = [WorkoutSet(id: UUID(), reps: 5, weight: 105, kind: .work)]
        let result = achievements(forSets: sets, baseline: baseline)
        XCTAssertEqual(result, [.heaviestWeight])
    }

    func testBeatingRepsOnly() {
        let baseline = PRBaseline(heaviestWeight: 100, mostReps: 10, bestOneRM: 130)
        let sets = [WorkoutSet(id: UUID(), reps: 12, weight: 80, kind: .work)]
        let result = achievements(forSets: sets, baseline: baseline)
        XCTAssertEqual(result, [.mostReps])
    }

    func testBeatingOneRMOnly() {
        let baseline = PRBaseline(heaviestWeight: 100, mostReps: 10, bestOneRM: 180)
        let sets = [WorkoutSet(id: UUID(), reps: 3, weight: 120, kind: .work)]
        let result = achievements(forSets: sets, baseline: baseline)
        XCTAssertEqual(result, [.bestOneRM])
    }

    func testMultipleAchievementsInOneWorkout() {
        let baseline = PRBaseline(heaviestWeight: 90, mostReps: 8, bestOneRM: 150)
        let sets = [WorkoutSet(id: UUID(), reps: 9, weight: 95, kind: .work)]
        let result = achievements(forSets: sets, baseline: baseline)
        XCTAssertEqual(Set(result), Set([.heaviestWeight, .mostReps, .bestOneRM]))
    }

    func testTiesDoNotCountAsNewPRs() {
        let baseline = PRBaseline(heaviestWeight: 100, mostReps: 10, bestOneRM: 160)
        let sets = [WorkoutSet(id: UUID(), reps: 10, weight: 100, kind: .work)]
        let result = achievements(forSets: sets, baseline: baseline)
        XCTAssertTrue(result.isEmpty)
    }
}
