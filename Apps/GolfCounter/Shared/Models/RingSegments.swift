/// 링에 그릴 세그먼트 구성 — 링 한 바퀴가 파, 타수 하나가 한 칸이다 (spec §6).
/// UI 프레임워크를 import하지 않아 색도 자체 enum이고, 색 매핑은 `StrokeRing`이 한다.
struct RingSegments: Equatable {
    enum Kind: Equatable {
        case swing
        case putt
        case empty
    }

    /// 주 링. 길이는 항상 `par`다.
    let slots: [Kind]
    /// 바깥 초과 링. 비어 있으면 그리지 않는다. 길이는 최대 `par`다.
    let overflow: [Kind]

    init(par: Int, strokes: Int, putts: Int) {
        guard par > 0 else {
            slots = []
            overflow = []
            return
        }

        // 퍼트는 타수에 포함되는 개념이므로 타수를 넘을 수 없다.
        // 정상 경로로는 안 생기지만, 어긋난 값이 들어와도 인덱스를 벗어나지 않게 클램프한다.
        let totalStrokes = max(strokes, 0)
        let totalPutts = min(max(putts, 0), totalStrokes)
        let swingCount = totalStrokes - totalPutts

        /// 0-based 타수 순번에 해당하는 종류. 스윙을 먼저, 퍼팅을 나중에 배치한다.
        func kind(atStrokeIndex index: Int) -> Kind {
            index < swingCount ? .swing : .putt
        }

        slots = (0 ..< par).map { index in
            index < min(totalStrokes, par) ? kind(atStrokeIndex: index) : .empty
        }

        // 초과가 파를 또 넘으면 바깥 링은 한 바퀴에서 멈춘다.
        let overflowCount = min(max(totalStrokes - par, 0), par)
        overflow = (0 ..< overflowCount).map { index in
            kind(atStrokeIndex: par + index)
        }
    }
}
