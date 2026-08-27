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
        let service = MatchConnectivity.shared
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
        let service = MatchConnectivity.shared
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

    /// 경기 중이 아니어도 브로드캐스트한다 — 폰이 모드 선택·결과 화면에서도 수치를 유지하도록.
    @Test @MainActor func metricsBroadcastEvenWhenNotPlaying() {
        let vm = WorkoutSessionViewModel()
        vm.broadcastMetrics()
        #expect(vm.lastMetrics != nil)
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

    /// 칼로리는 경기 구간 델타가 아니라 워크아웃 누적값을 그대로 싣는다.
    /// 경기 구간 값은 저장 시점에 종료값 - 시작값으로 만든다.
    @Test @MainActor func metricsCaloriesAreWorkoutCumulative() {
        let healthKit = WorkoutSessionService(configuration: .tennis)
        healthKit.setLiveMetricsForTesting(calories: 100)
        let vm = WorkoutSessionViewModel(healthKit: healthKit)
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        healthKit.setLiveMetricsForTesting(calories: 150)
        vm.broadcastMetrics()
        #expect(vm.lastMetrics?.activeCalories == 150)
    }

    @MainActor
    @Test func currentMetricsReflectsHealthKitValues() async throws {
        let healthKit = WorkoutSessionService(configuration: .tennis)
        let viewModel = WorkoutSessionViewModel(healthKit: healthKit)

        healthKit.setLiveMetricsForTesting(heartRate: 142, calories: 245, basalCalories: 58, elapsedSeconds: 1523)
        try await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.currentMetrics.elapsedSeconds == 1523)
        #expect(viewModel.currentMetrics.activeCalories == 245)
        #expect(viewModel.currentMetrics.totalCalories == 303)
        #expect(viewModel.currentMetrics.heartRate == 142)
    }

    /// 총 칼로리 = 활동 + 휴식, 역시 누적값.
    @Test @MainActor func metricsTotalCaloriesIncludeBasalCumulative() {
        let healthKit = WorkoutSessionService(configuration: .tennis)
        healthKit.setLiveMetricsForTesting(calories: 100, basalCalories: 20)
        let vm = WorkoutSessionViewModel(healthKit: healthKit)
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        healthKit.setLiveMetricsForTesting(calories: 150, basalCalories: 40)
        vm.broadcastMetrics()
        #expect(vm.lastMetrics?.totalCalories == 190)
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

    /// 경기가 끝난 뒤에도 워크아웃이 살아있으면 계속 브로드캐스트한다.
    @Test @MainActor func metricsBroadcastAfterMatchFinished() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.finishMatch(result: .win, completedSets: [SetScore(my: 6, your: 3)])
        vm.broadcastMetrics()
        #expect(vm.lastMetrics != nil)
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

    // MARK: - Pause 명령 수신

    /// 자기 세션의 명령이면 적용한다.
    @Test @MainActor func pauseCommandAppliedWhenSessionMatches() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))

        let applied = vm.handleIncomingPauseCommandForTest(
            WorkoutPauseMessage(sessionId: vm.activeSessionIdForTest, shouldPause: true)
        )

        #expect(applied == true)
    }

    /// 재개 명령도 같은 경로로 적용된다.
    @Test @MainActor func resumeCommandAppliedWhenSessionMatches() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))

        let applied = vm.handleIncomingPauseCommandForTest(
            WorkoutPauseMessage(sessionId: vm.activeSessionIdForTest, shouldPause: false)
        )

        #expect(applied == true)
    }

    /// 다른 세션의 pause 명령은 무시한다 (죽은 세션·경합 방지).
    @Test @MainActor func pauseCommandIgnoredWhenSessionIdMismatch() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))

        let applied = vm.handleIncomingPauseCommandForTest(
            WorkoutPauseMessage(sessionId: UUID(), shouldPause: true)
        )

        #expect(applied == false)
    }

    /// mirror는 진행 중인 매치를 끝낼 권한이 없다. 로컬로 리셋해버리면 driver는 계속 경기 중인데
    /// mirror만 모드선택으로 빠져 두 기기가 어긋난다 (sendMatchReset은 isDriver 가드에 막혀 나가지도 않는다).
    @Test @MainActor func mirrorCannotResetPlayingMatchLocally() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), isRemote: true) // mirror
        vm.startNewMatch()
        guard case .playing = vm.phase else {
            Issue.record("mirror의 로컬 리셋은 무시되고 playing이 유지되어야 함")
            return
        }
    }

    /// 위 가드가 driver의 정상 리셋까지 막으면 안 된다.
    @Test @MainActor func driverCanResetPlayingMatchLocally() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)) // driver
        vm.startNewMatch()
        guard case .modeSelection = vm.phase else {
            Issue.record("driver는 진행 중인 매치를 끝낼 수 있어야 함")
            return
        }
    }

    /// driver가 보낸 matchReset 수신 경로(notifyRemote: false)는 mirror에도 그대로 적용되어야 한다.
    @Test @MainActor func mirrorAppliesIncomingMatchReset() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), isRemote: true) // mirror
        vm.startNewMatch(notifyRemote: false) // handleIncomingMatchReset이 타는 경로
        guard case .modeSelection = vm.phase else {
            Issue.record("driver의 matchReset을 받으면 mirror도 모드선택으로 돌아가야 함")
            return
        }
    }

    /// 종료된 매치의 결과 화면은 mirror도 스스로 닫을 수 있다 — 진행 중인 매치가 아니라 어긋날 상태가 없다.
    /// (가드를 .playing으로 한정한 이유. 여기까지 막으면 mirror가 결과 화면에 갇힌다.)
    @Test @MainActor func mirrorCanLeaveFinishedResultScreen() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), isRemote: true) // mirror
        vm.finishMatch(result: .win, completedSets: [SetScore(my: 6, your: 4)])
        vm.startNewMatch()
        guard case .modeSelection = vm.phase else {
            Issue.record("mirror도 결과 화면에서는 빠져나올 수 있어야 함")
            return
        }
    }

    // MARK: - 워크아웃 id 유지 + matchId

    /// 스펙 1-4 재현: 폰이 driver로 1경기를 진행한 뒤 워치에서 2경기를 시작하면,
    /// 워치가 폰에서 채택한 워크아웃 id를 버리고 자기 것으로 되돌아갔다.
    /// 이 id는 Summary의 워크아웃 그룹핑 키라 갈리면 누적 지표가 과대 집계된다.
    @Test @MainActor func startMatchAfterRemoteDrivenMatchKeepsActiveSessionId() {
        let vm = WorkoutSessionViewModel()
        let phoneSessionId = UUID()
        let options = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)

        vm.startMatch(options: options, sessionId: phoneSessionId, isRemote: true)
        #expect(vm.activeSessionIdForTest == phoneSessionId)

        vm.startNewMatch(notifyRemote: false)
        vm.startMatch(options: options)

        #expect(vm.activeSessionIdForTest == phoneSessionId)
    }

    @Test @MainActor func startNewMatchIssuesNewMatchId() {
        let vm = WorkoutSessionViewModel()
        let options = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)

        vm.startMatch(options: options)
        let first = vm.currentSession()?.id

        vm.startNewMatch(notifyRemote: false)
        vm.startMatch(options: options)
        let second = vm.currentSession()?.id

        #expect(first != nil)
        #expect(second != nil)
        #expect(first != second)
    }

    @Test @MainActor func restartMatchIssuesNewMatchIdButKeepsSessionId() {
        let vm = WorkoutSessionViewModel()
        let options = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)

        vm.startMatch(options: options)
        let firstMatchId = vm.currentSession()?.id
        let sessionId = vm.activeSessionIdForTest
        vm.finishMatch(result: .win, completedSets: [SetScore(my: 6, your: 4)])

        vm.restartMatch()

        #expect(vm.currentSession()?.id != firstMatchId)
        #expect(vm.activeSessionIdForTest == sessionId)
    }

    @Test @MainActor func startMatchAdoptsRemoteMatchId() {
        let vm = WorkoutSessionViewModel()
        let remoteMatchId = UUID()

        vm.startMatch(
            options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false),
            sessionId: UUID(),
            matchId: remoteMatchId,
            isRemote: true
        )

        #expect(vm.currentSession()?.id == remoteMatchId)
    }

    /// 최종 리뷰 Finding 2 재현: race 가드가 activeSessionId가 아니라 workoutSessionId와 비교하고 있었다.
    /// 상대 id를 채택한 뒤에는 두 기기가 같은 activeSessionId를 주고받는데, 가드는 이 기기의
    /// 최초(전송된 적 없는) workoutSessionId와 비교해 임의로 판정 → 양쪽 다 driver로 남는 split-brain.
    /// 같은 워크아웃의 새 경기 시작 메시지는 레이스 대상이 아니라 항상 수용해야 한다.
    @Test @MainActor func acceptsNewMatchFromPeerInSameAdoptedWorkout() throws {
        let vm = WorkoutSessionViewModel()
        let options = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)
        // 랜덤 UUID는 항상 이 값보다 작다 → 수정 전 가드라면 반드시 거절되는 조건.
        let peerSessionId = try #require(UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF"))

        // 1) 상대(peer)의 워크아웃 id를 채택한다 → activeSessionId != workoutSessionId
        vm.startMatch(options: options, sessionId: peerSessionId, isRemote: true)
        // 2) 이 기기가 다음 경기의 driver가 된다 (워크아웃 id는 채택한 값 유지)
        vm.startNewMatch(notifyRemote: false)
        vm.startMatch(options: options)
        #expect(vm.isDriver)
        #expect(vm.activeSessionIdForTest == peerSessionId)
        #expect(vm.activeSessionIdForTest != vm.workoutSessionId)

        // 3) 같은 워크아웃 안에서 상대가 다음 경기를 시작한다
        let peerMatchId = UUID()
        vm.applyIncomingSessionStartForTest(SessionStartMessage(
            sessionId: peerSessionId,
            matchId: peerMatchId,
            options: MatchOptions(mode: .bestOfThree, noAdRule: false, noTieRule: false),
            workoutStartDate: Date()
        ))

        #expect(vm.currentSession()?.id == peerMatchId) // 거절되지 않고 수용
        #expect(vm.scoreVM.options.mode == .bestOfThree)
        #expect(!vm.isDriver) // 한쪽이 mirror로 양보 → split-brain 아님
        #expect(vm.activeSessionIdForTest == peerSessionId)
    }

    @Test @MainActor func matchEndMessageCarriesMatchIntervalAndCumulativeMetrics() {
        let vm = WorkoutSessionViewModel()
        vm.healthKit.setLiveMetricsForTesting(calories: 350, basalCalories: 70, elapsedSeconds: 600)
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))

        vm.healthKit.setLiveMetricsForTesting(calories: 600, basalCalories: 130, elapsedSeconds: 1500)
        vm.finishMatch(result: .win, completedSets: [SetScore(my: 6, your: 4)])

        guard let session = vm.currentSession() else {
            Issue.record("currentSession이 없음")
            return
        }
        #expect(session.elapsedAtStart == 600)
        #expect(session.elapsedAtEnd == 1500)
        #expect(session.kcalAtEnd == 600)
        #expect(session.totalKcalAtEnd == 730)
    }
}
