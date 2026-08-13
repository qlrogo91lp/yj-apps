@testable import GolfCounter_Watch_App
import Testing

struct StrokeUndoTests {
    @Test func 초기에는_되돌릴게_없다() {
        let undo = StrokeUndo()

        #expect(undo.canUndo == false)
        #expect(undo.history.isEmpty)
    }

    @Test func 기록하면_되돌릴게_생긴다() {
        var undo = StrokeUndo()

        undo.record(.swing)

        #expect(undo.canUndo)
        #expect(undo.history == [.swing])
    }

    @Test func pop은_마지막에_기록한_모드를_역순으로_돌려준다() {
        var undo = StrokeUndo()
        undo.record(.swing)
        undo.record(.putt)
        undo.record(.swing)

        #expect(undo.pop() == .swing)
        #expect(undo.pop() == .putt)
        #expect(undo.pop() == .swing)
        #expect(undo.canUndo == false)
    }

    @Test func 비어있으면_pop은_nil이다() {
        var undo = StrokeUndo()

        #expect(undo.pop() == nil)
    }

    @Test func clear하면_되돌릴게_없다() {
        var undo = StrokeUndo()
        undo.record(.swing)
        undo.record(.putt)

        undo.clear()

        #expect(undo.canUndo == false)
        #expect(undo.history.isEmpty)
    }
}
