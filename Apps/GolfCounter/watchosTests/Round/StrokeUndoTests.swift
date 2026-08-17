@testable import GolfCounter_Watch_App
import Testing

struct StrokeUndoTests {
    @Test func 초기에는_되돌릴게_없다() {
        let undo = StrokeUndo()

        #expect(undo.canUndo(hole: 0) == false)
        #expect(undo.history(forHole: 0).isEmpty)
    }

    @Test func 기록하면_되돌릴게_생긴다() {
        var undo = StrokeUndo()

        undo.record(.swing, hole: 0)

        #expect(undo.canUndo(hole: 0))
        #expect(undo.history(forHole: 0) == [.swing])
    }

    @Test func pop은_마지막에_기록한_모드를_역순으로_돌려준다() {
        var undo = StrokeUndo()
        undo.record(.swing, hole: 0)
        undo.record(.putt, hole: 0)
        undo.record(.swing, hole: 0)

        #expect(undo.pop(hole: 0) == .swing)
        #expect(undo.pop(hole: 0) == .putt)
        #expect(undo.pop(hole: 0) == .swing)
        #expect(undo.canUndo(hole: 0) == false)
    }

    @Test func 비어있으면_pop은_nil이다() {
        var undo = StrokeUndo()

        #expect(undo.pop(hole: 0) == nil)
    }

    @Test func 존재하지_않는_홀도_되돌릴게_없다() {
        var undo = StrokeUndo()
        undo.record(.swing, hole: 0)

        #expect(undo.canUndo(hole: 3) == false)
        #expect(undo.history(forHole: 3).isEmpty)
        #expect(undo.pop(hole: 3) == nil)
    }

    @Test func 다른_홀의_기록은_서로_독립적이다() {
        var undo = StrokeUndo()
        undo.record(.swing, hole: 0)
        undo.record(.putt, hole: 1)

        #expect(undo.pop(hole: 1) == .putt)
        #expect(undo.canUndo(hole: 1) == false)
        #expect(undo.canUndo(hole: 0))
        #expect(undo.history(forHole: 0) == [.swing])
    }

    @Test func 한_홀을_모두_pop해도_다른_홀은_영향받지_않는다() {
        var undo = StrokeUndo()
        undo.record(.swing, hole: 0)
        undo.record(.putt, hole: 0)
        undo.record(.swing, hole: 5)

        _ = undo.pop(hole: 0)
        _ = undo.pop(hole: 0)

        #expect(undo.canUndo(hole: 0) == false)
        #expect(undo.canUndo(hole: 5))
    }
}
