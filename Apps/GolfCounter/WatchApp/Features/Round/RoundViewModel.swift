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

    @Published private var progress: HoleProgress
    @Published var inputMode: StrokeInputMode = .swing
    /// 파가 이미 설정된 홀에서 [Par] 버튼으로 파 선택 화면을 다시 띄운 상태.
    @Published private(set) var isEditingPar = false
    /// 되돌리기 기록. `canUndo`가 이 값에서 파생되므로 `@Published`여야
    /// 뷰가 취소 버튼의 등장·퇴장을 관찰할 수 있다.
    /// 프로퍼티명이 `undo`가 아닌 이유: 같은 이름의 메서드 `undo()`와 충돌한다.
    @Published private var undoStack = StrokeUndo()

    let startedAt: Date
    var courseName: String?

    private let publisher: RoundSnapshotPublishing

    init(holeCount: Int = 18,
         startedAt: Date = Date(),
         courseName: String? = nil,
         publisher: RoundSnapshotPublishing = RoundSnapshotPublisher())
    {
        self.startedAt = startedAt
        self.courseName = courseName
        self.publisher = publisher
        progress = HoleProgress(holeCount: holeCount)
    }

    /// App Group 스냅샷으로 라운드를 되살린다 (spec §12).
    /// 워크아웃 세션은 복구하지 않고 새로 시작하므로, 여기서는 스코어 상태만 복원한다.
    init(resuming snapshot: RoundSnapshot,
         publisher: RoundSnapshotPublishing = RoundSnapshotPublisher())
    {
        startedAt = snapshot.startedAt
        courseName = snapshot.courseName
        self.publisher = publisher
        progress = HoleProgress(holeCount: snapshot.holeCount,
                                holeScores: snapshot.holeScores,
                                holePars: snapshot.holePars,
                                puttCounts: snapshot.puttCounts,
                                currentHoleIndex: snapshot.currentHoleIndex)
    }

    // MARK: - 표시값

    var currentHoleNumber: Int {
        progress.currentHoleNumber
    }

    var currentScore: Int {
        progress.currentScore
    }

    var currentPutts: Int {
        progress.currentPutts
    }

    /// 0은 "아직 파가 설정되지 않음"을 뜻한다.
    var currentPar: Int {
        progress.currentPar
    }

    /// 화면 분기 조건은 "홀 이동 방향"이 아니라 "이 홀에 파가 있는가" 하나다 (spec §4).
    var phase: Phase {
        if isEditingPar { return .parSelection }
        return currentPar == 0 ? .parSelection : .counting
    }

    var canGoToPreviousHole: Bool {
        progress.canGoToPreviousHole
    }

    var canUndo: Bool {
        undoStack.canUndo
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
                      currentHoleIndex: progress.currentHoleIndex,
                      holeScores: progress.holeScores,
                      holePars: progress.holePars,
                      puttCounts: progress.puttCounts)
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
        undoStack.record(inputMode)
        progress.apply(inputMode)
        publishSnapshot()
    }

    /// 현재 홀의 마지막 입력을 되돌린다. 입력의 정확한 역연산이다.
    /// 상태를 바꾸는 모든 경로가 스냅샷을 발행한다는 규칙을 따라 마지막에 발행한다.
    func undo() {
        guard let mode = undoStack.pop() else { return }
        progress.revert(mode)
        publishSnapshot()
    }

    // MARK: - 파 선택

    func selectPar(_ par: Int) {
        progress.setPar(par)
        isEditingPar = false
        publishSnapshot()
    }

    func beginParEditing() {
        isEditingPar = true
    }

    // MARK: - 홀 이동

    func goToNextHole() {
        progress.advanceToNextHole()
        resetHoleLocalState()
        publishSnapshot()
    }

    func goToPreviousHole() {
        guard progress.canGoToPreviousHole else { return }
        progress.retreatToPreviousHole()
        resetHoleLocalState()
        publishSnapshot()
    }

    /// 파 선택 화면의 "이전" 버튼에서 호출한다.
    /// 방금 실수로 다음 홀에 진입해 아직 아무 값도 입력하지 않은 홀(phantom hole)이면
    /// 그 홀을 배열에서 완전히 제거하고 이전 홀로 돌아가, mis-tap 이전 상태를 그대로 복원한다.
    /// 반대로 이미 점수가 있던 홀을 [Par] 버튼으로 재편집(`beginParEditing()`)하는 중이라면
    /// 지울 phantom hole이 없으므로 일반 `goToPreviousHole()`과 동일하게 동작한다.
    func cancelToPreviousHole() {
        guard progress.canGoToPreviousHole else { return }

        guard !isEditingPar, progress.isPristinePhantomHole else {
            goToPreviousHole()
            return
        }

        progress.removePhantomHoleAndRetreat()
        resetHoleLocalState()
        publishSnapshot()
    }

    /// 홀을 옮기면 입력 모드는 스윙으로 리셋되고(spec §3), 진행 중이던 파 편집은 취소된다.
    /// 되돌리기 기록도 함께 비운다 — 되돌리기 스코프는 현재 홀이다 (spec §7).
    private func resetHoleLocalState() {
        inputMode = .swing
        isEditingPar = false
        undoStack.clear()
    }
}
