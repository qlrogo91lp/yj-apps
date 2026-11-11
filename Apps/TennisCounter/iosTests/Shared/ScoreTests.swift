import Foundation
@testable import TennisCounter
import Testing

struct ScoreTests {
    @Test @MainActor func snapshotRestoresNormalPoints() {
        let score = Score()
        score.addPoint(.me) // 15-0
        score.addPoint(.me) // 30-0
        let snapshot = score.makeSnapshot()

        score.addPoint(.opponent) // 30-15
        score.addPoint(.opponent) // 30-30
        score.restore(snapshot)

        #expect(score.myDisplayScore == "30")
        #expect(score.yourDisplayScore == "0")
    }

    @Test @MainActor func snapshotRestoresTieBreakState() {
        let score = Score()
        score.setTieBreakMode()
        score.addPoint(.me)
        score.addPoint(.me)
        let snapshot = score.makeSnapshot()

        score.addPoint(.opponent)
        score.restore(snapshot)

        #expect(score.gameMode == .tieBreak)
        #expect(score.myTieBreak == 2)
        #expect(score.yourTieBreak == 0)
    }

    @Test @MainActor func snapshotTakenInNormalModeRestoresGameMode() {
        let score = Score()
        score.addPoint(.me) // normal 모드, 15-0
        let snapshot = score.makeSnapshot()

        score.setTieBreakMode() // 타이브레이크 진입
        score.addPoint(.me)
        score.restore(snapshot)

        #expect(score.gameMode == .normal)
        #expect(score.myDisplayScore == "15")
    }

    @Test @MainActor func snapshotRestoresAdvantage() {
        let score = Score()
        score.noAdRule = false
        for _ in 0 ..< 3 {
            score.addPoint(.me); score.addPoint(.opponent)
        } // 40-40 듀스
        score.addPoint(.me) // AD-40
        let snapshot = score.makeSnapshot()

        score.addPoint(.opponent) // 듀스로 복귀
        score.restore(snapshot)

        #expect(score.myDisplayScore == "AD")
        #expect(score.yourDisplayScore == "40")
    }

    @Test @MainActor func matchTieBreak_endsAtTenWithTwoPointLead() {
        let score = Score()
        score.setTieBreakMode(target: Score.matchTieBreakTarget)

        var results: [PlayerSide?] = []
        for _ in 0 ..< 10 {
            results.append(score.addPoint(.me))
        }

        #expect(results[8] == nil) // 9-0
        #expect(results[9] == .me) // 10-0
    }

    @Test @MainActor func matchTieBreak_continuesPastNineAll() {
        let score = Score()
        score.setTieBreakMode(target: Score.matchTieBreakTarget)

        var lastResult: PlayerSide?
        for _ in 0 ..< 9 {
            score.addPoint(.me)
            lastResult = score.addPoint(.opponent)
        } // 9-9

        #expect(lastResult == nil) // 9-9
        #expect(score.addPoint(.me) == nil) // 10-9
        #expect(score.addPoint(.me) == .me) // 11-9
    }

    @Test @MainActor func standardTieBreak_stillEndsAtSeven() {
        let score = Score()
        score.setTieBreakMode()

        var result: PlayerSide?
        for _ in 0 ..< 7 {
            result = score.addPoint(.me)
        }

        #expect(result == .me)
    }

    @Test @MainActor func snapshotRestoresTieBreakTarget() {
        let score = Score()
        score.setTieBreakMode(target: Score.matchTieBreakTarget)
        let snapshot = score.makeSnapshot()

        score.reset()
        score.restore(snapshot)

        var results: [PlayerSide?] = []
        for _ in 0 ..< 10 {
            results.append(score.addPoint(.me))
        }

        #expect(results[6] == nil) // 7-0, 목표가 10 이라 아직 안 끝남
        #expect(results[9] == .me) // 10-0
    }

    @Test @MainActor func resetRestoresStandardTieBreakTarget() {
        let score = Score()
        score.setTieBreakMode(target: Score.matchTieBreakTarget)
        score.reset()
        score.setTieBreakMode()

        var result: PlayerSide?
        for _ in 0 ..< 7 {
            result = score.addPoint(.me)
        }

        #expect(result == .me)
    }

    @Test func setScore_isMatchTieBreakOnlyFromTen() {
        #expect(SetScore(my: 10, your: 7).isMatchTieBreak)
        #expect(SetScore(my: 7, your: 10).isMatchTieBreak)
        #expect(SetScore(my: 11, your: 9).isMatchTieBreak)
        #expect(!SetScore(my: 7, your: 6).isMatchTieBreak)
        #expect(!SetScore(my: 6, your: 4).isMatchTieBreak)
        #expect(!SetScore(my: 7, your: 5).isMatchTieBreak)
    }
}
