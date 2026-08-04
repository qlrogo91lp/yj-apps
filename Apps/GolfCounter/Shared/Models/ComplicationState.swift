import Foundation

/// 컴플리케이션이 그릴 표시값. 진행 중 스냅샷(`RoundSnapshot`) 유무로 평상시/라운드 중을 가른다 (spec §7).
/// 위젯 타깃에는 테스트 타깃이 없으므로, 표시 로직을 Shared로 내려 watchosTests에서 검증한다.
struct ComplicationState: Equatable {
    let isRoundActive: Bool
    let holeNumber: Int
    let totalStrokes: Int
    let relativeToPar: Int

    init(snapshot: RoundSnapshot?) {
        isRoundActive = snapshot != nil
        holeNumber = snapshot?.currentHoleNumber ?? 0
        totalStrokes = snapshot?.totalStrokes ?? 0
        relativeToPar = snapshot?.relativeToPar ?? 0
    }

    var holeText: String {
        "H\(holeNumber)"
    }

    var relativeToParText: String {
        ScoreFormat.relativeToPar(relativeToPar)
    }

    var strokesText: String {
        "\(totalStrokes)타"
    }
}
