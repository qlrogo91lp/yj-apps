import Testing
@testable import WorkoutCore

struct WorkoutDeletionServiceTests {
    @Test func deleteWorkoutsWithEmptyUUIDsReturnsNothingToDelete() async {
        let service = WorkoutDeletionService()

        let outcome = await service.deleteWorkouts(uuids: [])

        #expect(outcome == .nothingToDelete)
    }

    @Test func deletionOutcomesCompareByCase() {
        #expect(WorkoutDeletionOutcome.deleted == .deleted)
        #expect(WorkoutDeletionOutcome.failed != .notAuthorized)
    }
}
