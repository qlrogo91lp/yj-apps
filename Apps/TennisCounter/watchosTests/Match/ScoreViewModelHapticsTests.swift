@testable import TennisCounter_Watch_App
import Testing

/// 포인트 4개로 게임 하나를 끝내는 헬퍼. noAd 라 듀스 없이 4연속이면 게임이다.
@MainActor
private func winGame(_ vm: ScoreViewModel, for side: PlayerSide) {
    for _ in 0 ..< 4 {
        vm.addPoint(side)
    }
}

struct ScoreViewModelHapticsTests {
    private let oneSet = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)

    @Test @MainActor func pointPlaysClickForBothSides() {
        let spy = HapticsSpy()
        let vm = ScoreViewModel(options: oneSet, haptics: spy)

        vm.addPoint(.me)
        vm.addPoint(.opponent)

        #expect(spy.played == [.point, .point])
    }

    @Test @MainActor func undoPlaysUndo() {
        let spy = HapticsSpy()
        let vm = ScoreViewModel(options: oneSet, haptics: spy)
        vm.addPoint(.me)

        vm.undo()

        #expect(spy.played.last == .undo)
    }

    @Test @MainActor func undoWithNothingToUndoStaysSilent() {
        let spy = HapticsSpy()
        let vm = ScoreViewModel(options: oneSet, haptics: spy)

        vm.undo()

        #expect(spy.played.isEmpty)
    }

    @Test @MainActor func gameWinningPointPlaysGameWonOnly() {
        let spy = HapticsSpy()
        let vm = ScoreViewModel(options: oneSet, haptics: spy)

        winGame(vm, for: .me)

        // 마지막 포인트는 .point 가 아니라 .gameWon 하나만
        #expect(spy.played == [.point, .point, .point, .gameWon])
    }

    @Test @MainActor func setWinningPointPlaysSetWonOnly() {
        let spy = HapticsSpy()
        // 세트 하나로 매치가 끝나지 않도록 3세트 매치
        let vm = ScoreViewModel(
            options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false),
            haptics: spy
        )

        for _ in 0 ..< 6 {
            winGame(vm, for: .me)
        } // 6-0 세트

        #expect(spy.played.last == .setWon)
        #expect(spy.played.count(where: { $0 == .gameWon }) == 5) // 6번째 게임은 .setWon 으로 흡수
        #expect(vm.mySetScore == 1)
    }

    @Test @MainActor func matchWinningPointPlaysMatchFinishedOnly() {
        let spy = HapticsSpy()
        let vm = ScoreViewModel(options: oneSet, haptics: spy)

        for _ in 0 ..< 6 {
            winGame(vm, for: .me)
        } // 원세트 6-0 → 매치 종료

        #expect(spy.played.last == .matchFinished(.win))
        #expect(!spy.played.contains(.setWon)) // 세트·게임은 매치 종료에 흡수
    }

    @Test @MainActor func opponentMatchWinPlaysLoss() {
        let spy = HapticsSpy()
        let vm = ScoreViewModel(options: oneSet, haptics: spy)

        for _ in 0 ..< 6 {
            winGame(vm, for: .opponent)
        }

        #expect(spy.played.last == .matchFinished(.loss))
    }

    @Test @MainActor func remoteStateStaysSilent() {
        let spy = HapticsSpy()
        let vm = ScoreViewModel(options: oneSet, haptics: spy)

        vm.applyRemoteState(ScoreState(
            myScore: 1, yourScore: 0,
            myGameScore: 3, yourGameScore: 2,
            mySetScore: 0, yourSetScore: 0,
            completedSets: [], isTieBreak: false
        ))

        #expect(spy.played.isEmpty)
    }
}
