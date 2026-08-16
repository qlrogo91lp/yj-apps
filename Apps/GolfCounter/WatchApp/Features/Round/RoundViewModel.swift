import Combine
import Foundation

/// 라운드 진행 상태와 카운터 불변식(spec §3)을 담는다.
/// UI 프레임워크를 import하지 않으며, 스냅샷 발행은 주입된 publisher에 위임한다.
@MainActor
final class RoundViewModel: ObservableObject {
    enum Phase: Equatable {
        case parSelection
        case counting
        case summary
    }

    @Published private var progress: HoleProgress
    @Published var inputMode: StrokeInputMode = .swing
    /// 파가 이미 설정된 홀에서 [Par] 버튼으로 파 선택 화면을 다시 띄운 상태.
    @Published private(set) var isEditingPar = false
    /// 되돌리기 기록. `canUndo`가 이 값에서 파생되므로 `@Published`여야
    /// 뷰가 취소 버튼의 등장·퇴장을 관찰할 수 있다.
    /// 프로퍼티명이 `undo`가 아닌 이유: 같은 이름의 메서드 `undo()`와 충돌한다.
    @Published private var undoStack = StrokeUndo()
    /// 종료 확인을 거쳤는지. `phase`가 이 값에서 `.summary`로 갈린다.
    @Published private var isFinished = false
    /// 워크아웃 집계값. `stopWorkout()`이 1~3초 걸려 뒤늦게 도착한다 (spec §2 결정 9).
    @Published private(set) var metrics: RoundMetrics?
    /// "저장 & 전송"을 눌렀지만 메트릭이 아직 안 와 대기 중인 상태. 요약이 "전송 중…"을 띄운다.
    @Published private(set) var isTransmitting = false
    /// 전송(또는 0홀 폐기)이 끝나 홈으로 돌아가도 되는 상태. View가 이걸 보고 dismiss한다.
    @Published private(set) var didComplete = false

    /// 라운드 식별자. 스냅샷에 실려 복구를 넘어 유지되고, iOS가 이 값으로 재전송을 거른다.
    let id: UUID
    /// 종료 확인을 누른 시점. 요약 체류 시간이나 전송 지연이 라운드 길이에 섞이지 않는다 (spec §4).
    private(set) var endedAt: Date?
    let startedAt: Date
    var courseName: String?

    private let publisher: RoundSnapshotPublishing
    private let transmitter: RoundTransmitting

    init(id: UUID = UUID(),
         holeCount: Int = 18,
         startedAt: Date = Date(),
         courseName: String? = nil,
         publisher: RoundSnapshotPublishing = RoundSnapshotPublisher(),
         transmitter: RoundTransmitting = RoundTransmitter())
    {
        self.id = id
        self.startedAt = startedAt
        self.courseName = courseName
        self.publisher = publisher
        self.transmitter = transmitter
        progress = HoleProgress(holeCount: holeCount)
    }

    /// App Group 스냅샷으로 라운드를 되살린다 (spec §12).
    /// 워크아웃 세션은 복구하지 않고 새로 시작하므로, 여기서는 스코어 상태만 복원한다.
    /// `id`를 이어받아야 "전송 후 스냅샷 삭제 전 크래시 → 복구 후 재전송"을 iOS가 걸러낸다.
    init(resuming snapshot: RoundSnapshot,
         publisher: RoundSnapshotPublishing = RoundSnapshotPublisher(),
         transmitter: RoundTransmitting = RoundTransmitter())
    {
        id = snapshot.id
        startedAt = snapshot.startedAt
        courseName = snapshot.courseName
        self.publisher = publisher
        self.transmitter = transmitter
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
    /// 종료 확인을 거치면 그 위에 요약이 덮인다.
    var phase: Phase {
        if isFinished { return .summary }
        if isEditingPar { return .parSelection }
        return currentPar == 0 ? .parSelection : .counting
    }

    var canGoToPreviousHole: Bool {
        progress.canGoToPreviousHole
    }

    var canGoToNextHole: Bool {
        progress.canGoToNextHole
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
        RoundSnapshot(id: id,
                      holeCount: progress.holeCount,
                      startedAt: startedAt,
                      courseName: courseName,
                      currentHoleIndex: progress.currentHoleIndex,
                      holeScores: progress.holeScores,
                      holePars: progress.holePars,
                      puttCounts: progress.puttCounts)
    }

    // MARK: - 요약 표시값 (전부 트림 후 기준)

    /// 파가 기록된 홀 수(유효 홀 개수) — iOS `GolfRound.recordedHoleCount`와 같은 규칙이다.
    /// 종료 확인 문구와 요약 헤더가 쓴다. **전송되는 홀 수와는 다를 수 있다** — `trimmed()`는
    /// 말단만 자르므로 중간에 건너뛴 홀이 있으면 전송 배열이 이 값보다 길 수 있다.
    var recordedHoleCount: Int {
        snapshot.recordedHoleCount
    }

    var trimmedTotalStrokes: Int {
        snapshot.trimmed().totalStrokes
    }

    var trimmedTotalPutts: Int {
        snapshot.trimmed().totalPutts
    }

    var trimmedRelativeToPar: Int {
        snapshot.trimmed().relativeToPar
    }

    // MARK: - 라이프사이클

    /// 라운드 화면 진입 시 1회. 컴플리케이션이 곧바로 "라운드 중"으로 바뀌게 한다.
    func start() {
        publishSnapshot()
    }

    /// 종료 확인에서 호출한다. 워크아웃 종료는 View가 async로 진행하고,
    /// 도착한 결과는 `applyMetrics(_:)`로 들어온다 (spec §7).
    ///
    /// 먼저 미타구 홀을 정규화한다 — `isFinished`를 세우는 순간 요약 화면이 뜨므로,
    /// 그 전에 배열이 정리돼 있어야 요약과 전송이 같은 값을 본다 (spec §5.2).
    ///
    /// 정규화를 종료 확인 **다이얼로그보다 뒤**에 두는 것이 핵심이다. 다이얼로그 전에
    /// 현재 홀의 파를 지우면 `phase`가 파 선택으로 튕겨, 사용자가 "취소"를 눌렀을 때
    /// 홀이 초기화된 것처럼 보인다 (spec §5.1). 다이얼로그 문구의 정확성은
    /// `recordedHoleCount`가 집계 대상 홀을 세는 것으로 이미 보장된다.
    func finishRound() {
        progress.clearUnplayedHoles()
        publishSnapshot()
        endedAt = Date()
        isFinished = true
    }

    /// 워크아웃 종료 결과가 도착했을 때 View가 부른다.
    /// `nil`이면 0으로 채운다 — HealthKit 거부·워크아웃 미시작·복구 라운드에서 정상 경로다 (spec §8).
    func applyMetrics(_ result: RoundMetrics?) {
        metrics = result ?? .empty
        guard isTransmitting, let metrics else { return }
        transmit(with: metrics)
    }

    /// 요약의 "저장 & 전송". 메트릭이 아직 안 왔으면 대기만 하고, 도착하면 이어서 보낸다
    /// (버튼을 죽이지 않는다 — spec §2 결정 9).
    func saveAndTransmit() {
        // 시작하자마자 종료한 경우. iOS에 빈 라운드를 만들지 않는다 (spec §2 결정 10).
        guard recordedHoleCount > 0 else {
            publisher.clear()
            didComplete = true
            return
        }
        guard let metrics else {
            isTransmitting = true
            return
        }
        transmit(with: metrics)
    }

    /// 요약의 "저장 안 함". 전송하지 않고 스냅샷만 지운 뒤 홈으로 돌아간다.
    ///
    /// `saveAndTransmit()`의 0홀 경로와 같은 처리지만, 이쪽은 기록이 있는데도 사용자가
    /// 명시적으로 버리기를 고른 경우다 — 뷰가 확인 다이얼로그를 한 번 거치게 한다.
    /// 스냅샷을 지우므로 다음 실행 때 복구되지 않는다.
    func discardRound() {
        publisher.clear()
        isTransmitting = false
        didComplete = true
    }

    private func transmit(with metrics: RoundMetrics) {
        let trimmed = snapshot.trimmed()
        transmitter.send(RoundCompletedMessage(id: id,
                                               startedAt: startedAt,
                                               endedAt: endedAt ?? Date(),
                                               courseName: courseName,
                                               holeScores: trimmed.holeScores,
                                               holePars: trimmed.holePars,
                                               puttCounts: trimmed.puttCounts,
                                               metrics: metrics))
        publisher.clear()
        isTransmitting = false
        didComplete = true
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

    /// 카운터의 [Par] 버튼으로 시작한 파 재편집을 취소하고 카운터로 돌아간다.
    /// 홀은 옮기지 않고 파 값도 그대로 둔다 — 편집 진입 자체를 무르는 것뿐이다.
    ///
    /// 스냅샷을 발행하지 않는다: `isEditingPar`는 화면 분기용 UI 상태일 뿐
    /// `RoundSnapshot`에 들어가지 않으므로 발행할 변경이 없다 (`beginParEditing()`도 같다).
    func cancelParEditing() {
        isEditingPar = false
    }

    // MARK: - 홀 이동

    func goToNextHole() {
        guard progress.canGoToNextHole else { return }
        progress.advanceToNextHole()
        resetHoleLocalState()
        publishSnapshot()
    }

    /// 한 타도 치지 않은 홀을 건너뛴다 — 파를 0으로 되돌려 "진짜 건너뛴 홀"로 만든 뒤 다음 홀로 간다.
    ///
    /// 파를 남긴 채 넘어가면 그 홀이 기록 홀 수에 잡히고(spec §3 유효 홀), 오버파에서는
    /// 집계 대상 홀이 아니라 빠져서 "18홀인데 17홀치 스코어"라는 어긋남이 생긴다.
    /// 파를 지우면 두 지표가 같은 홀 집합을 보게 된다.
    ///
    /// 타수가 이미 있는 홀에는 아무 일도 하지 않는다 — 파를 지우면 그 타수가 미아가 되고,
    /// `par == 0 && score > 0`은 어느 화면도 해석할 수 없는 상태다.
    func skipCurrentHole() {
        guard progress.canGoToNextHole, progress.currentScore == 0 else { return }
        progress.setPar(0)
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

    /// 파 선택 화면의 "이전" 버튼에서 호출하되, **새 홀 진입 경로에서만** 쓰인다.
    /// 방금 실수로 다음 홀에 진입해 아직 아무 값도 입력하지 않은 홀(phantom hole)이면
    /// 그 홀을 배열에서 완전히 제거하고 이전 홀로 돌아가, mis-tap 이전 상태를 그대로 복원한다.
    ///
    /// 카운터의 [Par] 버튼으로 이미 점수가 있던 홀을 재편집(`beginParEditing()`)하는
    /// 경로의 백버튼은 `cancelParEditing()`을 호출하므로 이 메서드를 거치지 않는다.
    /// 아래 `isEditingPar` 분기는 그래서 UI 관점에서는 죽은 경로다 — `isEditingPar`가
    /// 참인 채로 이 메서드가 호출되는 경우에도 정의된 동작(`goToPreviousHole()`과 동일)을
    /// 갖도록 남겨둔 방어용 fallback일 뿐, 실제 화면 흐름이 타는 경로가 아니다.
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
