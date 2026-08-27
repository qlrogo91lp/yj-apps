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
}
