import Foundation
import SwiftData
@testable import TennisCounter
import Testing

@MainActor
final class LiveActivitySpy: LiveActivityControlling {
    var startCount = 0
    var endCount = 0
    func start(mode _: MatchFormat) {
        startCount += 1
    }

    func update(from _: ScoreState, score _: Score) {}
    func end() {
        endCount += 1
    }
}

@Suite(.serialized)
struct WorkoutSessionViewModelTests {
    @Test @MainActor func remoteSessionStartStartsLiveActivityOnce() {
        let spy = LiveActivitySpy()
        let vm = WorkoutSessionViewModel(liveActivity: spy)
        vm.applyIncomingSessionStartForTest(SessionStartMessage(
            sessionId: UUID(),
            options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false),
            workoutStartDate: Date()
        ))
        #expect(spy.startCount == 1)
    }

    @Test @MainActor func matchSessionStartMatchSetsPlayingPhase() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        guard case let .playing(options) = vm.phase else {
            Issue.record("Expected .playing phase")
            return
        }
        #expect(options.mode == .oneSet)
        #expect(options.noAdRule == true)
    }

    @Test @MainActor func matchSessionFinishMatchSetsFinishedPhase() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.finishMatch(result: .win, completedSets: [(my: 6, your: 4)])
        guard case let .finished(session) = vm.phase else {
            Issue.record("Expected .finished phase")
            return
        }
        #expect(session.result == .win)
        #expect(session.completedSets.count == 1)
        #expect(session.mySetScore == 1)
        #expect(session.yourSetScore == 0)
    }

    @Test @MainActor func matchSessionStartNewMatchResetsToModeSelection() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false))
        vm.startNewMatch()
        guard case .modeSelection = vm.phase else {
            Issue.record("Expected .modeSelection after startNewMatch")
            return
        }
    }

    @Test @MainActor func matchSessionEndSessionResetsState() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.endSession()
        guard case .modeSelection = vm.phase else {
            Issue.record("Expected .modeSelection after endSession")
            return
        }
        #expect(vm.elapsedSeconds == 0)
    }

    @Test @MainActor func matchSessionPauseStopsTimer() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.pauseSession()
        #expect(vm.isPaused == true)
        vm.resumeSession()
        #expect(vm.isPaused == false)
    }

    @Test @MainActor func matchSessionRestartMatchUsesSameFormat() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .bestOfThree, noAdRule: false, noTieRule: true))
        vm.finishMatch(result: .loss, completedSets: [(my: 3, your: 6)])
        vm.restartMatch()
        guard case let .playing(newOptions) = vm.phase else {
            Issue.record("Expected .playing after restartMatch")
            return
        }
        #expect(newOptions.mode == .bestOfThree)
    }

    @Test @MainActor func matchSessionRestartWithoutMatchIsNoOp() {
        let vm = WorkoutSessionViewModel()
        vm.restartMatch()
        guard case .modeSelection = vm.phase else {
            Issue.record("Expected .modeSelection — restartMatch without prior match should be no-op")
            return
        }
    }

    @Test @MainActor func matchSessionSaveWithNoSessionIsNoOp() {
        let vm = WorkoutSessionViewModel()
        #expect(vm.saveCurrentMatch() == false) // _currentSession nil이면 guard에서 false 리턴
    }

    @Test @MainActor func saveCurrentMatchReturnsTrueOnSuccess() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Match.self, SetRecord.self, configurations: config)
        MatchPersistenceService.shared.configure(with: ModelContext(container))

        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.finishMatch(result: .win, completedSets: [(my: 6, your: 4)])

        #expect(vm.saveCurrentMatch() == true)
    }

    @Test @MainActor func matchSessionFinishMatchStoresSession() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.finishMatch(result: .win, completedSets: [(my: 6, your: 4)])
        guard case let .finished(session) = vm.phase else {
            Issue.record("Expected .finished")
            return
        }
        #expect(session.result == .win)
        #expect(session.mySetScore == 1)
        #expect(session.yourSetScore == 0)
        #expect(session.completedSets.count == 1)
    }

    @Test @MainActor func matchSessionStartNewMatchClearsToModeSelection() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.finishMatch(result: .win, completedSets: [(my: 6, your: 4)])
        vm.startNewMatch()
        guard case .modeSelection = vm.phase else {
            Issue.record("Expected .modeSelection after startNewMatch")
            return
        }
    }

    @Test @MainActor func workoutSessionRemoteWorkoutEndedDefaultsFalse() {
        let vm = WorkoutSessionViewModel()
        #expect(vm.remoteWorkoutEnded == false)
    }

    @Test @MainActor func workoutSessionEndSessionDuringPlayingResetsPhase() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.endSession()
        guard case .modeSelection = vm.phase else {
            Issue.record("Expected .modeSelection after remote workout end triggers endSession")
            return
        }
        #expect(vm.elapsedSeconds == 0)
        #expect(vm.isPaused == false)
    }

    @Test @MainActor func workoutSessionEndSessionAfterFinishedResetsPhase() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.finishMatch(result: .win, completedSets: [(my: 6, your: 4)])
        vm.endSession()
        guard case .modeSelection = vm.phase else {
            Issue.record("Expected .modeSelection after endSession from .finished state")
            return
        }
    }

    @Test @MainActor func workoutSessionEndSessionResetsMetrics() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.endSession()
        #expect(vm.metrics.calories == 0)
        #expect(vm.metrics.heartRate == 0)
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

    @Test @MainActor func restartMatchResetsScoreVM() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.scoreVM.myGameScore = 3
        vm.scoreVM.mySetScore = 1
        vm.scoreVM.completedSets = [(my: 6, your: 4)]

        vm.restartMatch()

        #expect(vm.scoreVM.myGameScore == 0)
        #expect(vm.scoreVM.mySetScore == 0)
        #expect(vm.scoreVM.completedSets.isEmpty)
    }

    @Test @MainActor func startMatchAppliesOptionsToScoreVM() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .bestOfThree, noAdRule: false, noTieRule: false))
        #expect(vm.scoreVM.options.mode == .bestOfThree)
        #expect(vm.scoreVM.score.noAdRule == false)
    }

    @Test @MainActor func driverIgnoresRemoteScoreState() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)) // isDriver = true
        vm.scoreVM.myGameScore = 2
        vm.applyIncomingScoreStateForTest(ScoreState(
            myScore: 0, yourScore: 0, myGameScore: 5, yourGameScore: 5,
            mySetScore: 0, yourSetScore: 0, completedSets: [], isTieBreak: false
        ))
        #expect(vm.scoreVM.myGameScore == 2) // driver는 덮어쓰지 않음
    }

    @Test @MainActor func mirrorAppliesRemoteScoreState() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), isRemote: true) // mirror
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
        vm.finishMatch(result: .win, completedSets: [(my: 6, your: 4)])
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
        vm.finishMatch(result: .win, completedSets: [(my: 6, your: 4)])
        vm.applyIncomingScoreStateForTest(ScoreState(
            myScore: 30, yourScore: 15, myGameScore: 3, yourGameScore: 2,
            mySetScore: 0, yourSetScore: 0, completedSets: [], isTieBreak: false
        ))
        #expect(vm.scoreVM.myGameScore == 0) // 경기 종료 후 늦게 도착한 상태는 무시
    }

    @Test @MainActor func driverYieldsToSmallerSessionIdOnSimultaneousStart() throws {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)) // driver, random sessionId
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
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)) // driver, random sessionId
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
        vm.handleIncomingWorkoutEndForTest(UUID()) // 다른 세션
        #expect(vm.remoteWorkoutEnded == false)
        guard case .playing = vm.phase else {
            Issue.record("playing 유지 기대")
            return
        }
    }

    @Test @MainActor func workoutEndAppliedWhenSessionIdMatches() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.handleIncomingWorkoutEndForTest(vm.currentSessionIdForTest)
        #expect(vm.remoteWorkoutEnded == true)
    }

    @Test @MainActor func workoutEndAppliedBeforeAnyMatchStarted() {
        // 매치를 한 번도 시작하지 않으면 sessionId가 상대와 동기화되지 않으므로, 어떤 id가 와도 종료를 수용해야 한다.
        let vm = WorkoutSessionViewModel()
        vm.handleIncomingWorkoutEndForTest(UUID())
        #expect(vm.remoteWorkoutEnded == true)
    }

    @Test @MainActor func staleWorkoutEndDoesNotEndCurrentMatch() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        let unrelated = UUID()
        vm.handleIncomingWorkoutEndForTest(unrelated)
        #expect(vm.remoteWorkoutEnded == false)
        guard case .playing = vm.phase else {
            Issue.record("stale 종료는 무시되고 playing 유지되어야 함")
            return
        }
    }

    @Test @MainActor func remoteStartMatchSyncsSessionIdForWorkoutEnd() {
        let vm = WorkoutSessionViewModel()
        let sid = UUID()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), sessionId: sid, isRemote: true)
        #expect(vm.currentSessionIdForTest == sid) // 원격 채택 시 sessionId가 상대 것으로 동기화됨
        vm.handleIncomingWorkoutEndForTest(sid)
        #expect(vm.remoteWorkoutEnded == true) // 동기화된 sessionId 덕분에 workoutEnd가 적용됨
    }

    @Test @MainActor func remoteStartMatchSyncsSessionIdForMatchReset() {
        let vm = WorkoutSessionViewModel()
        let sid = UUID()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), sessionId: sid, isRemote: true)
        vm.handleIncomingMatchResetForTest(sid)
        guard case .modeSelection = vm.phase else {
            Issue.record("sessionId 동기화 후 matchReset이 적용되어 모드선택으로 복귀해야 함")
            return
        }
    }

    @Test @MainActor func mirrorMatchResetReturnsToModeSelection() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), isRemote: true) // mirror
        vm.handleIncomingMatchResetForTest(vm.currentSessionIdForTest)
        guard case .modeSelection = vm.phase else {
            Issue.record("미러는 드라이버의 matchReset을 받으면 모드선택으로 돌아가야 함")
            return
        }
    }

    @Test @MainActor func driverIgnoresMatchReset() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)) // driver
        vm.handleIncomingMatchResetForTest(vm.currentSessionIdForTest)
        guard case .playing = vm.phase else {
            Issue.record("드라이버는 matchReset을 무시하고 playing 유지해야 함")
            return
        }
    }

    @Test @MainActor func mirrorIgnoresMatchResetForDifferentSession() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), isRemote: true) // mirror
        vm.handleIncomingMatchResetForTest(UUID()) // 다른 세션
        guard case .playing = vm.phase else {
            Issue.record("다른 세션의 matchReset은 무시되어야 함")
            return
        }
    }

    @Test @MainActor func saveFromWatchPersistsMatch() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Match.self, SetRecord.self, configurations: config)
        MatchPersistenceService.shared.configure(with: ModelContext(container))

        let sid = UUID()
        let msg = MatchEndMessage(
            sessionId: sid,
            result: "win",
            completedSets: [[6, 4]],
            startedAt: Date(timeIntervalSince1970: 1_000_000),
            endedAt: Date(timeIntervalSince1970: 1_001_800),
            durationSeconds: 1800,
            calories: 200,
            averageHeartRate: 130,
            mode: "oneSet",
            noAdRule: true
        )

        let vm = WorkoutSessionViewModel()
        vm.saveFromWatchForTest(msg)

        let saved = try MatchPersistenceService.shared.fetchByWorkoutSession(sid)
        #expect(saved.count == 1)
    }
}
