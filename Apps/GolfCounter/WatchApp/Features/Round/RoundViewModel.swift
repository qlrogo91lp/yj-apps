import Combine
import Foundation

/// 라운드 진행 상태와 카운터 불변식(spec §3)을 담는다.
/// UI 프레임워크를 import하지 않으며, 스냅샷 발행은 주입된 publisher에 위임한다.
@MainActor
final class RoundViewModel: ObservableObject {
    enum Phase: Equatable {
        case parSelection
        case counting
    }

    @Published private(set) var holeScores: [Int]
    @Published private(set) var holePars: [Int]
    @Published private(set) var puttCounts: [Int]
    @Published private(set) var currentHoleIndex: Int
    @Published var inputMode: StrokeInputMode = .swing

    let startedAt: Date
    var courseName: String?

    private let publisher: RoundSnapshotPublishing

    init(startedAt: Date = Date(),
         courseName: String? = nil,
         publisher: RoundSnapshotPublishing = RoundSnapshotPublisher())
    {
        self.startedAt = startedAt
        self.courseName = courseName
        self.publisher = publisher
        holeScores = [0]
        holePars = [0]
        puttCounts = [0]
        currentHoleIndex = 0
    }

    // MARK: - 표시값

    var currentHoleNumber: Int { currentHoleIndex + 1 }
    var currentScore: Int { holeScores[currentHoleIndex] }
    var currentPutts: Int { puttCounts[currentHoleIndex] }
    /// 0은 "아직 파가 설정되지 않음"을 뜻한다.
    var currentPar: Int { holePars[currentHoleIndex] }
    var totalStrokes: Int { snapshot.totalStrokes }
    var relativeToPar: Int { snapshot.relativeToPar }

    var snapshot: RoundSnapshot {
        RoundSnapshot(startedAt: startedAt,
                      courseName: courseName,
                      currentHoleIndex: currentHoleIndex,
                      holeScores: holeScores,
                      holePars: holePars,
                      puttCounts: puttCounts)
    }

    // MARK: - 카운터

    func incrementStroke() {
        switch inputMode {
        case .swing:
            holeScores[currentHoleIndex] += 1
        case .putt:
            holeScores[currentHoleIndex] += 1
            puttCounts[currentHoleIndex] += 1
        }
    }

    func decrementStroke() {
        switch inputMode {
        case .swing:
            // 퍼팅은 타수에 포함되는 개념이라, 타수가 퍼팅 수 아래로 내려갈 수 없다.
            // puttCounts는 항상 0 이상이므로 하한 0도 이 식이 함께 보장한다.
            holeScores[currentHoleIndex] = max(holeScores[currentHoleIndex] - 1, puttCounts[currentHoleIndex])
        case .putt:
            guard puttCounts[currentHoleIndex] > 0 else { return }
            holeScores[currentHoleIndex] -= 1
            puttCounts[currentHoleIndex] -= 1
        }
    }
}
