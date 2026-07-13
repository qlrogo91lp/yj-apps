import Foundation
@testable import TennisCounter_Watch_App
import Testing
import WorkoutCore

struct WorkoutSessionViewModelTests {
    @Test @MainActor func finishMatchSetsPhaseImmediately() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.finishMatch(result: .draw, completedSets: [])

        guard case .finished = vm.phase else {
            Issue.record("Expected .finished phase immediately after finishMatch")
            return
        }
    }

    @Test @MainActor func finishMatchPopulatesSetScores() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false))

        let sets = [
            SetScore(my: 6, your: 3),
            SetScore(my: 2, your: 6),
        ]
        vm.finishMatch(result: .draw, completedSets: sets)

        guard case let .finished(session) = vm.phase else {
            Issue.record("Expected .finished phase")
            return
        }
        #expect(session.mySetScore == 1)
        #expect(session.yourSetScore == 1)
    }

    @Test @MainActor func restartMatchReusesOptions() {
        let vm = WorkoutSessionViewModel()
        let options = MatchOptions(mode: .bestOfThree, noAdRule: false, noTieRule: true)
        vm.startMatch(options: options)
        vm.finishMatch(result: .win, completedSets: [SetScore(my: 6, your: 3)])

        vm.restartMatch()

        guard case let .playing(newOptions) = vm.phase else {
            Issue.record("Expected .playing phase after restartMatch")
            return
        }
        #expect(newOptions.mode == .bestOfThree)
        #expect(newOptions.noAdRule == false)
        #expect(newOptions.noTieRule == true)
    }

    @Test @MainActor func endWorkoutClearsCurrentSession() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        #expect(vm.currentSession() != nil)
        vm.endWorkout()
        #expect(vm.currentSession() == nil)
    }

    @Test @MainActor func endWorkoutDuringMatchInProgressClearsSession() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .bestOfThree, noAdRule: false, noTieRule: true))
        vm.endWorkout()
        #expect(vm.currentSession() == nil)
    }

    @Test @MainActor func endWorkoutTwiceIsIdempotent() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.endWorkout()
        vm.endWorkout()
        #expect(vm.currentSession() == nil)
        #expect(vm.isPaused == false)
    }

    @Test @MainActor func endWorkoutDoesNotResetPhase() {
        // Watch의 endWorkout은 HealthKit 세션만 종료하고 phase는 변경하지 않음
        // startNewMatch()가 phase를 .modeSelection으로 리셋하는 역할
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.endWorkout()
        guard case .playing = vm.phase else {
            Issue.record("endWorkout should not reset phase — phase should remain .playing")
            return
        }
    }

    @Test @MainActor func startOwnMatchClearsStaleRemoteScoreState() {
        let service = WatchConnectivityService.shared
        service.receivedScoreState = ScoreState(
            myScore: 15, yourScore: 0,
            myGameScore: 3, yourGameScore: 2,
            mySetScore: 1, yourSetScore: 0,
            completedSets: [], isTieBreak: false
        )
        defer { service.receivedScoreState = nil }

        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), isRemote: false)

        #expect(service.receivedScoreState == nil)
    }

    @Test @MainActor func remoteMatchStartDoesNotClearScoreState() {
        let service = WatchConnectivityService.shared
        let existing = ScoreState(
            myScore: 15, yourScore: 0,
            myGameScore: 3, yourGameScore: 2,
            mySetScore: 1, yourSetScore: 0,
            completedSets: [], isTieBreak: false
        )
        service.receivedScoreState = existing
        defer { service.receivedScoreState = nil }

        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), isRemote: true)

        #expect(service.receivedScoreState != nil)
    }

    @Test @MainActor func remoteWorkoutEndedDefaultsFalse() {
        let vm = WorkoutSessionViewModel()
        #expect(vm.remoteWorkoutEnded == false)
    }

    // MARK: - Metrics Broadcast

    @Test @MainActor func metricsNotBroadcastWhenNotPlaying() {
        let vm = WorkoutSessionViewModel()
        vm.broadcastMetrics()
        #expect(vm.lastMetrics == nil)
    }

    @Test @MainActor func metricsBroadcastWhenPlaying() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.broadcastMetrics()
        #expect(vm.lastMetrics != nil)
    }

    @Test @MainActor func metricsHeartRateReflectsHealthKit() {
        let healthKit = WorkoutSessionService(configuration: .tennis)
        healthKit.setLiveMetricsForTesting(heartRate: 140)
        let vm = WorkoutSessionViewModel(healthKit: healthKit)
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.broadcastMetrics()
        #expect(vm.lastMetrics?.heartRate == 140)
    }

    @Test @MainActor func metricsCaloriesAreNetOfStart() {
        let healthKit = WorkoutSessionService(configuration: .tennis)
        healthKit.setLiveMetricsForTesting(calories: 100)
        let vm = WorkoutSessionViewModel(healthKit: healthKit)
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        healthKit.setLiveMetricsForTesting(calories: 150)
        vm.broadcastMetrics()
        #expect(vm.lastMetrics?.calories == 50)
    }

    @Test @MainActor func restartMatchResetsScoreVM() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.scoreVM.myGameScore = 3
        vm.scoreVM.mySetScore = 1
        vm.scoreVM.completedSets = [SetScore(my: 6, your: 4)]

        vm.restartMatch()

        #expect(vm.scoreVM.myGameScore == 0)
        #expect(vm.scoreVM.mySetScore == 0)
        #expect(vm.scoreVM.completedSets.isEmpty)
    }

    @Test @MainActor func metricsNotBroadcastAfterMatchFinished() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.finishMatch(result: .win, completedSets: [SetScore(my: 6, your: 3)])
        vm.broadcastMetrics()
        #expect(vm.lastMetrics == nil)
    }

    @Test @MainActor func driverIgnoresRemoteScoreState() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.scoreVM.myGameScore = 2
        vm.applyIncomingScoreStateForTest(ScoreState(
            myScore: 0, yourScore: 0, myGameScore: 5, yourGameScore: 5,
            mySetScore: 0, yourSetScore: 0, completedSets: [], isTieBreak: false
        ))
        #expect(vm.scoreVM.myGameScore == 2)
    }

    @Test @MainActor func mirrorAppliesRemoteScoreState() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), isRemote: true)
        vm.applyIncomingScoreStateForTest(ScoreState(
            myScore: 30, yourScore: 15, myGameScore: 3, yourGameScore: 2,
            mySetScore: 0, yourSetScore: 0, completedSets: [], isTieBreak: false
        ))
        #expect(vm.scoreVM.myGameScore == 3)
        #expect(vm.scoreVM.score.myScore == 30)
    }

    @Test @MainActor func restartMatchPreservesMirrorRole() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), isRemote: true) // mirror
        vm.finishMatch(result: .win, completedSets: [SetScore(my: 6, your: 4)])
        vm.restartMatch()
        vm.applyIncomingScoreStateForTest(ScoreState(
            myScore: 30, yourScore: 15, myGameScore: 3, yourGameScore: 2,
            mySetScore: 0, yourSetScore: 0, completedSets: [], isTieBreak: false
        ))
        #expect(vm.scoreVM.myGameScore == 3) // restartMatch 후에도 mirror 역할이 유지되어 원격 상태를 적용
    }

    @Test @MainActor func mirrorIgnoresScoreStateAfterMatchFinished() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), isRemote: true) // mirror
        vm.finishMatch(result: .win, completedSets: [SetScore(my: 6, your: 4)])
        vm.applyIncomingScoreStateForTest(ScoreState(
            myScore: 30, yourScore: 15, myGameScore: 3, yourGameScore: 2,
            mySetScore: 0, yourSetScore: 0, completedSets: [], isTieBreak: false
        ))
        #expect(vm.scoreVM.myGameScore == 0) // 경기 종료 후 늦게 도착한 상태는 무시
    }

    @Test @MainActor func driverYieldsToSmallerSessionIdOnSimultaneousStart() throws {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)) // driver, workoutSessionId는 init에서 랜덤 생성
        let smallerId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        vm.applyIncomingSessionStartForTest(SessionStartMessage(
            sessionId: smallerId,
            options: MatchOptions(mode: .bestOfThree, noAdRule: false, noTieRule: false),
            workoutStartDate: Date()
        ))
        #expect(vm.scoreVM.options.mode == .bestOfThree) // 더 작은 sessionId가 우선해 mirror로 전환
    }

    @Test @MainActor func driverKeepsDrivingAgainstLargerSessionIdOnSimultaneousStart() throws {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)) // driver
        let largerId = try #require(UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF"))
        vm.applyIncomingSessionStartForTest(SessionStartMessage(
            sessionId: largerId,
            options: MatchOptions(mode: .bestOfThree, noAdRule: false, noTieRule: false),
            workoutStartDate: Date()
        ))
        #expect(vm.scoreVM.options.mode == .oneSet) // 더 큰 sessionId는 우선권이 없어 무시되고 driver 유지
    }

    @Test @MainActor func workoutEndIgnoredWhenSessionIdMismatch() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.handleIncomingWorkoutEndForTest(UUID())
        #expect(vm.remoteWorkoutEnded == false)
    }

    @Test @MainActor func workoutEndAppliedWhenSessionIdMatches() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.handleIncomingWorkoutEndForTest(vm.activeSessionIdForTest)
        #expect(vm.remoteWorkoutEnded == true)
    }

    @Test @MainActor func workoutEndAppliedBeforeAnyMatchStarted() {
        // 매치를 한 번도 시작하지 않으면 sessionId가 상대와 동기화되지 않으므로, 어떤 id가 와도 종료를 수용해야 한다.
        let vm = WorkoutSessionViewModel()
        vm.handleIncomingWorkoutEndForTest(UUID())
        #expect(vm.remoteWorkoutEnded == true)
    }

    @Test @MainActor func restartMatchAsMirrorPreservesActiveSessionIdForWorkoutEnd() {
        // mirror가 Rematch를 직접 눌러도 driver의 sessionId를 잃지 않아야 한다 (회귀 방지).
        let vm = WorkoutSessionViewModel()
        let driverSessionId = UUID()
        vm.startMatch(
            options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false),
            sessionId: driverSessionId,
            isRemote: true
        ) // mirror
        vm.finishMatch(result: .win, completedSets: [SetScore(my: 6, your: 4)])
        vm.restartMatch()
        #expect(vm.activeSessionIdForTest == driverSessionId)
        vm.handleIncomingWorkoutEndForTest(driverSessionId)
        #expect(vm.remoteWorkoutEnded == true)
    }

    // MARK: - Save Ack State Reset

    @Test @MainActor func startNewMatchResetsSaveAckState() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.saveCurrentMatch()
        vm.handleMatchSaveResultForTest(MatchSaveResultMessage(sessionId: vm.activeSessionId, success: true))
        #expect(vm.saveAckState == .succeeded)

        vm.startNewMatch()
        #expect(vm.saveAckState == .idle)
    }

    @Test @MainActor func restartMatchResetsSaveAckState() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.finishMatch(result: .win, completedSets: [SetScore(my: 6, your: 3)])
        vm.saveCurrentMatch()
        vm.handleMatchSaveResultForTest(MatchSaveResultMessage(sessionId: vm.activeSessionId, success: false))
        #expect(vm.saveAckState == .failed)

        vm.restartMatch()
        #expect(vm.saveAckState == .idle)
    }

    @Test @MainActor func staleAckIgnoredWhenSaveAckStateIsIdle() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.saveCurrentMatch()
        vm.handleMatchSaveResultForTest(MatchSaveResultMessage(sessionId: vm.activeSessionId, success: true))
        vm.restartMatch() // saveAckState → .idle

        // 이전 경기의 delayed ack가 동일 sessionId로 도착 — 무시해야 한다
        vm.handleMatchSaveResultForTest(MatchSaveResultMessage(sessionId: vm.activeSessionId, success: true))
        #expect(vm.saveAckState == .idle)
    }

    @Test @MainActor func staleTimeoutDoesNotFireAfterStartNewMatch() async throws {
        let vm = WorkoutSessionViewModel(ackTimeoutSeconds: 0.05)
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.saveCurrentMatch() // token=1, .pending

        vm.startNewMatch() // saveAckState → .idle, token invalidated
        #expect(vm.saveAckState == .idle)

        try await Task.sleep(nanoseconds: 150_000_000) // 0.15s > 0.05s 타임아웃
        #expect(vm.saveAckState == .idle) // 고아 타임아웃이 .idle을 .failed로 덮으면 안 된다
    }

    // MARK: - Save Ack

    @Test @MainActor func saveCurrentMatchStartsPending() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.saveCurrentMatch()
        #expect(vm.saveAckState == .pending)
    }

    @Test @MainActor func handleMatchSaveResultSucceeds() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.saveCurrentMatch()
        vm.handleMatchSaveResultForTest(MatchSaveResultMessage(sessionId: vm.activeSessionId, success: true))
        #expect(vm.saveAckState == .succeeded)
    }

    @Test @MainActor func handleMatchSaveResultIgnoredForMismatchedSession() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.saveCurrentMatch()
        vm.handleMatchSaveResultForTest(MatchSaveResultMessage(sessionId: UUID(), success: true))
        #expect(vm.saveAckState == .pending) // 다른 세션의 ack는 무시
    }

    @Test @MainActor func saveCurrentMatchTimesOutToFailedWhenNoAck() async throws {
        let vm = WorkoutSessionViewModel(ackTimeoutSeconds: 0.05)
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.saveCurrentMatch()
        #expect(vm.saveAckState == .pending)

        try await Task.sleep(nanoseconds: 150_000_000) // 0.15s > 0.05s 타임아웃
        #expect(vm.saveAckState == .failed)
    }

    @Test @MainActor func retryAfterTimeoutIgnoresStaleTimeout() async throws {
        let vm = WorkoutSessionViewModel(ackTimeoutSeconds: 0.05)
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))

        vm.saveCurrentMatch() // 시도 1
        try await Task.sleep(nanoseconds: 70_000_000) // 시도 1의 타임아웃 발동 (0.05s 경과)
        #expect(vm.saveAckState == .failed)

        vm.saveCurrentMatch() // 시도 2 (재시도) — pending으로 전환
        #expect(vm.saveAckState == .pending)
        vm.handleMatchSaveResultForTest(MatchSaveResultMessage(sessionId: vm.activeSessionId, success: true))
        #expect(vm.saveAckState == .succeeded)

        // 시도 1의 지연된 타임아웃 클로저가 혹시 아직 안 끝났더라도, 토큰이 달라 succeeded를 덮어쓰지 않아야 한다.
        try await Task.sleep(nanoseconds: 70_000_000)
        #expect(vm.saveAckState == .succeeded)
    }
}
