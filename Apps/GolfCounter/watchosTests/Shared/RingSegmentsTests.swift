@testable import GolfCounter_Watch_App
import Testing

struct RingSegmentsTests {
    @Test func 아직_안_쳤으면_전_슬롯이_비어있다() {
        let segments = RingSegments(par: 4, strokes: 0, putts: 0)

        #expect(segments.slots == [.empty, .empty, .empty, .empty])
        #expect(segments.overflow.isEmpty)
    }

    @Test func 파_이내면_친_만큼만_채워진다() {
        let segments = RingSegments(par: 4, strokes: 3, putts: 0)

        #expect(segments.slots == [.swing, .swing, .swing, .empty])
        #expect(segments.overflow.isEmpty)
    }

    @Test func 정확히_파면_꽉_차고_초과링이_없다() {
        let segments = RingSegments(par: 4, strokes: 4, putts: 0)

        #expect(segments.slots == [.swing, .swing, .swing, .swing])
        #expect(segments.overflow.isEmpty)
    }

    /// 모델은 입력 순서를 저장하지 않으므로 스윙을 먼저 그린다 (spec §6 알려진 한계).
    @Test func 퍼팅은_스윙_뒤에_그려진다() {
        let segments = RingSegments(par: 4, strokes: 5, putts: 2)

        #expect(segments.slots == [.swing, .swing, .swing, .putt])
        #expect(segments.overflow == [.putt])
    }

    /// 초과가 한 바퀴를 또 넘으면 바깥 링은 파 칸수에서 멈춘다. 정확한 값은 가운데 숫자가 담당한다.
    @Test func 초과가_한바퀴를_넘으면_바깥링은_파_칸수에서_멈춘다() {
        let segments = RingSegments(par: 3, strokes: 10, putts: 4)

        #expect(segments.slots.count == 3)
        #expect(segments.overflow.count == 3)
    }

    /// 퍼트가 타수보다 많은 값은 정상 경로로는 안 생기지만, 들어와도 인덱스를 벗어나면 안 된다.
    @Test func 퍼트가_타수보다_많아도_타수까지만_센다() {
        let segments = RingSegments(par: 4, strokes: 2, putts: 5)

        #expect(segments.slots == [.putt, .putt, .empty, .empty])
        #expect(segments.overflow.isEmpty)
    }

    /// 파 선택 화면이 파를 강제하므로 카운터에서 par 0은 안 생기지만, 나눗셈 방어는 필요하다.
    @Test func 파가_0이면_슬롯이_없다() {
        let segments = RingSegments(par: 0, strokes: 3, putts: 1)

        #expect(segments.slots.isEmpty)
        #expect(segments.overflow.isEmpty)
    }
}
