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
    /// 파가 이미 설정된 홀에서 [Par] 버튼으로 파 선택 화면을 다시 띄운 상태.
    @Published private(set) var isEditingPar = false
    /// 현재 홀에서 친 타의 종류 순서. 되돌리기의 유일한 상태다 (spec §7).
    ///
    /// `incrementStroke()`가 하는 일이 모드에 따라 (타수 +1) 또는 (타수 +1, 퍼트 +1)
    /// 두 가지뿐이므로, 어느 쪽이었는지만 알면 정확히 되돌릴 수 있다. 배열 전체를
    /// 복사할 필요가 없다.
    ///
    /// `@Published`인 이유: `canUndo`가 이 값에서 파생되므로, 뷰가 취소 버튼의
    /// 등장·퇴장을 관찰하려면 변경이 발행되어야 한다.
    @Published private var strokeHistory: [StrokeInputMode] = []

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

    /// App Group 스냅샷으로 라운드를 되살린다 (spec §12).
    /// 워크아웃 세션은 복구하지 않고 새로 시작하므로, 여기서는 스코어 상태만 복원한다.
    init(resuming snapshot: RoundSnapshot,
         publisher: RoundSnapshotPublishing = RoundSnapshotPublisher())
    {
        startedAt = snapshot.startedAt
        courseName = snapshot.courseName
        self.publisher = publisher
        holeScores = snapshot.holeScores
        holePars = snapshot.holePars
        puttCounts = snapshot.puttCounts
        currentHoleIndex = max(snapshot.currentHoleIndex, 0)
        ensureCapacityForCurrentHole()
    }

    // MARK: - 표시값

    var currentHoleNumber: Int {
        currentHoleIndex + 1
    }

    var currentScore: Int {
        holeScores[currentHoleIndex]
    }

    var currentPutts: Int {
        puttCounts[currentHoleIndex]
    }

    /// 0은 "아직 파가 설정되지 않음"을 뜻한다.
    var currentPar: Int {
        holePars[currentHoleIndex]
    }

    /// 화면 분기 조건은 "홀 이동 방향"이 아니라 "이 홀에 파가 있는가" 하나다 (spec §4).
    var phase: Phase {
        if isEditingPar { return .parSelection }
        return currentPar == 0 ? .parSelection : .counting
    }

    var canGoToPreviousHole: Bool {
        currentHoleIndex > 0
    }

    var canUndo: Bool {
        !strokeHistory.isEmpty
    }

    var totalStrokes: Int {
        snapshot.totalStrokes
    }

    var relativeToPar: Int {
        snapshot.relativeToPar
    }

    var snapshot: RoundSnapshot {
        RoundSnapshot(startedAt: startedAt,
                      courseName: courseName,
                      currentHoleIndex: currentHoleIndex,
                      holeScores: holeScores,
                      holePars: holePars,
                      puttCounts: puttCounts)
    }

    // MARK: - 라이프사이클

    /// 라운드 화면 진입 시 1회. 컴플리케이션이 곧바로 "라운드 중"으로 바뀌게 한다.
    func start() {
        publishSnapshot()
    }

    /// 라운드 종료. 스냅샷을 지워 컴플리케이션을 평상시로 되돌린다.
    /// 완료 라운드의 저장·전송은 plan ④ 범위다.
    func finish() {
        publisher.clear()
    }

    private func publishSnapshot() {
        publisher.publish(snapshot)
    }

    // MARK: - 카운터

    func incrementStroke() {
        strokeHistory.append(inputMode)
        switch inputMode {
        case .swing:
            holeScores[currentHoleIndex] += 1
        case .putt:
            holeScores[currentHoleIndex] += 1
            puttCounts[currentHoleIndex] += 1
        }
        publishSnapshot()
    }

    /// 현재 홀의 마지막 입력을 되돌린다. 입력의 정확한 역연산이다.
    /// 상태를 바꾸는 모든 경로가 스냅샷을 발행한다는 규칙을 따라 마지막에 발행한다.
    func undo() {
        guard let mode = strokeHistory.popLast() else { return }
        holeScores[currentHoleIndex] -= 1
        if mode == .putt {
            puttCounts[currentHoleIndex] -= 1
        }
        publishSnapshot()
    }

    // MARK: - 파 선택

    func selectPar(_ par: Int) {
        holePars[currentHoleIndex] = par
        isEditingPar = false
        publishSnapshot()
    }

    func beginParEditing() {
        isEditingPar = true
    }

    // MARK: - 홀 이동

    func goToNextHole() {
        currentHoleIndex += 1
        ensureCapacityForCurrentHole()
        resetHoleLocalState()
        publishSnapshot()
    }

    func goToPreviousHole() {
        guard canGoToPreviousHole else { return }
        currentHoleIndex -= 1
        resetHoleLocalState()
        publishSnapshot()
    }

    /// 파 선택 화면의 "이전" 버튼에서 호출한다.
    /// 방금 실수로 다음 홀에 진입해 아직 아무 값도 입력하지 않은 홀(phantom hole)이면
    /// 그 홀을 배열에서 완전히 제거하고 이전 홀로 돌아가, mis-tap 이전 상태를 그대로 복원한다.
    /// 반대로 이미 점수가 있던 홀을 [Par] 버튼으로 재편집(`beginParEditing()`)하는 중이라면
    /// 지울 phantom hole이 없으므로 일반 `goToPreviousHole()`과 동일하게 동작한다.
    func cancelToPreviousHole() {
        guard canGoToPreviousHole else { return }

        guard isPristinePhantomHole else {
            goToPreviousHole()
            return
        }

        holeScores.removeLast()
        holePars.removeLast()
        puttCounts.removeLast()
        currentHoleIndex -= 1
        resetHoleLocalState()
        publishSnapshot()
    }

    /// 현재 홀이 "방금 만들어졌고 아직 아무것도 입력되지 않은" phantom hole 상태인지 판단한다.
    /// 세 배열의 마지막 원소가 현재 홀과 정확히 일치할 때만 안전하게 pop할 수 있다.
    private var isPristinePhantomHole: Bool {
        !isEditingPar
            && currentScore == 0
            && currentPar == 0
            && currentPutts == 0
            && currentHoleIndex == holeScores.count - 1
            && currentHoleIndex == holePars.count - 1
            && currentHoleIndex == puttCounts.count - 1
    }

    /// 홀 배열 세 개의 길이를 현재 홀까지 맞춘다. 세 배열은 항상 같은 길이를 유지한다.
    private func ensureCapacityForCurrentHole() {
        let needed = currentHoleIndex + 1
        while holeScores.count < needed {
            holeScores.append(0)
        }
        while holePars.count < needed {
            holePars.append(0)
        }
        while puttCounts.count < needed {
            puttCounts.append(0)
        }
    }

    /// 홀을 옮기면 입력 모드는 스윙으로 리셋되고(spec §3), 진행 중이던 파 편집은 취소된다.
    /// 되돌리기 기록도 함께 비운다 — 되돌리기 스코프는 현재 홀이다 (spec §7).
    private func resetHoleLocalState() {
        inputMode = .swing
        isEditingPar = false
        strokeHistory.removeAll()
    }
}
