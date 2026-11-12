import Foundation
@testable import TennisCounter
import Testing
import WorkoutCore

struct MatchConnectivityTests {
    @Test func recentSessionStartIsNotStale() {
        let now = 1_000_000.0
        #expect(MatchConnectivity.isSessionStartStale(workoutStartDate: now - 60, now: now) == false)
    }

    @Test func veryOldSessionStartIsStale() {
        let now = 1_000_000.0
        #expect(MatchConnectivity.isSessionStartStale(workoutStartDate: now - 7 * 3600, now: now) == true)
    }

    @Test func missingSessionStartDateIsNotStale() {
        let now = 1_000_000.0
        #expect(MatchConnectivity.isSessionStartStale(workoutStartDate: nil, now: now) == false)
    }

    @Test func workoutEndMessageUsesResultEndDate() {
        let endedAt = Date(timeIntervalSince1970: 1_000_900)
        let result = WorkoutResult(durationSeconds: 900,
                                   caloriesBurned: 120,
                                   averageHeartRate: 135,
                                   endedAt: endedAt)

        let message = MatchConnectivity.workoutEndMessage(
            sessionId: UUID(),
            result: result,
            startedAt: Date(timeIntervalSince1970: 1_000_000)
        )

        #expect(message.endedAt == endedAt)
    }

    @Test func workoutEndMessageFallsBackToResultDurationWhenTotalElapsedSecondsIsNil() {
        let result = WorkoutResult(durationSeconds: 900, caloriesBurned: 120, averageHeartRate: 135)

        let message = MatchConnectivity.workoutEndMessage(
            sessionId: UUID(),
            result: result,
            startedAt: Date(timeIntervalSince1970: 1_000_000)
        )

        #expect(message.elapsedSeconds == 900)
    }

    /// Task 4b — 정지 제외 표시 기준 총시간이 있으면 그걸 쓴다. 정지를 포함한 `result.durationSeconds`(벽시계)는 덮인다.
    @Test func workoutEndMessageUsesTotalElapsedSecondsWhenProvided() {
        let result = WorkoutResult(durationSeconds: 900, caloriesBurned: 120, averageHeartRate: 135)

        let message = MatchConnectivity.workoutEndMessage(
            sessionId: UUID(),
            result: result,
            startedAt: Date(timeIntervalSince1970: 1_000_000),
            totalElapsedSeconds: 600
        )

        #expect(message.elapsedSeconds == 600)
    }

    /// 코드 리뷰 finding — stopWorkout() 이 이미 멈춘 세션에 대해 nil을 돌려줘도(워크아웃 없음),
    /// elapsedDisplay 는 이전 세션의 고정값을 그대로 들고 있을 수 있다. result 가 nil이면 이 메시지는
    /// "유효한 종료 결과 없음"이라는 뜻이어야 하는데, totalElapsedSeconds만 실리면
    /// WorkoutSessionRecorder 의 "값이 하나라도 있으면 저장" 가드를 통과해 빈 레코드가 기존 레코드를
    /// 덮어쓴다. result 가 nil이면 totalElapsedSeconds 도 무시한다.
    @Test func workoutEndMessageIgnoresTotalElapsedSecondsWhenResultIsNil() {
        let message = MatchConnectivity.workoutEndMessage(
            sessionId: UUID(),
            result: nil,
            startedAt: Date(timeIntervalSince1970: 1_000_000),
            totalElapsedSeconds: 600
        )

        #expect(message.elapsedSeconds == nil)
    }
}
