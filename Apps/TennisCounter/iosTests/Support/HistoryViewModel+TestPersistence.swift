@testable import TennisCounter
import WorkoutCore

extension HistoryViewModel {
    /// 기록 테스트용. 앱 싱글턴 대신 테스트 컨테이너에 묶인 저장소를 쓴다.
    convenience init(
        persistence: TestPersistence,
        workoutDeleter: any WorkoutDeleting = WorkoutDeletionService()
    ) {
        self.init(
            workoutDeleter: workoutDeleter,
            matchStore: persistence.matches,
            sessionStore: persistence.sessions
        )
    }
}
