import Foundation
@testable import HaruchiFit_Watch_App
import Testing

/// WC — 컴플리케이션이 읽는 스냅샷의 저장과, 그것을 표시값으로 바꾸는 규칙.
///
/// **위젯 타깃에는 테스트 타깃이 없다.** 그래서 표시 로직을 `WatchShared/` 로 내려
/// 여기서 검증한다 (골프가 같은 이유로 같은 선택을 했다).
struct WorkoutSnapshotTests {

    // MARK: - 저장소

    @Test("저장한 스냅샷을 그대로 읽어온다")
    func saveThenLoadRoundTrips() {
        let defaults = freshDefaults()
        let snapshot = makeSnapshot(mode: .cardio, isPaused: true, elapsedSeconds: 754)

        WorkoutSnapshotStore.save(snapshot, to: defaults)

        #expect(WorkoutSnapshotStore.load(from: defaults) == snapshot)
    }

    @Test("저장된 게 없으면 nil 이다")
    func loadWithoutSaveReturnsNil() {
        #expect(WorkoutSnapshotStore.load(from: freshDefaults()) == nil)
    }

    @Test("데이터가 깨져 있으면 nil 이다")
    func brokenDataLoadsAsNil() {
        let defaults = freshDefaults()
        defaults.set(Data("이건 스냅샷이 아니다".utf8), forKey: "workoutSnapshot")

        // 여기서 던지면 컴플리케이션이 진행 중 세션을 통째로 잃는다 — nil 로 떨어뜨린다.
        #expect(WorkoutSnapshotStore.load(from: defaults) == nil)
    }

    @Test("지우면 사라진다")
    func clearRemovesSnapshot() {
        let defaults = freshDefaults()
        WorkoutSnapshotStore.save(makeSnapshot(), to: defaults)

        WorkoutSnapshotStore.clear(from: defaults)

        #expect(WorkoutSnapshotStore.load(from: defaults) == nil)
    }

    // MARK: - 표시값

    @Test("스냅샷이 없으면 비활성이고 그릴 타이머도 없다")
    func stateWithoutSnapshotIsInactive() {
        let state = ComplicationState(snapshot: nil)

        #expect(state.isActive == false)
        #expect(state.timerReference == nil)
        #expect(state.isPaused == false)
    }

    @Test("스냅샷이 있으면 활성이고 유형과 정지 여부를 낸다")
    func stateWithSnapshotExposesModeAndPause() {
        let state = ComplicationState(snapshot: makeSnapshot(mode: .cardio, isPaused: true))

        #expect(state.isActive == true)
        #expect(state.mode == .cardio)
        #expect(state.isPaused == true)
    }

    @Test("타이머 기준점은 스냅샷을 뜬 시점에서 경과시간만큼 뒤다")
    func timerReferenceBacksOffByElapsed() {
        let capturedAt = Date(timeIntervalSince1970: 10000)
        let state = ComplicationState(snapshot: makeSnapshot(elapsedSeconds: 754, capturedAt: capturedAt))

        // 시작 시각으로 재면 일시정지한 만큼 부풀어 오른다 — 경과시간에서 거꾸로 잡는다.
        #expect(state.timerReference == Date(timeIntervalSince1970: 10000 - 754))
    }

    @Test("정지 중에 그릴 고정 문자열은 요약 화면과 같은 표기다")
    func elapsedTextMatchesSummaryFormat() {
        let state = ComplicationState(snapshot: makeSnapshot(elapsedSeconds: 754))

        #expect(state.elapsedText == "12:34")
    }

    // MARK: - Helpers

    /// 테스트마다 빈 저장소를 준다 — 하나가 남긴 값이 다음 테스트로 새면 순서에 의존하게 된다.
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "WorkoutSnapshotTests-\(UUID().uuidString)")!
    }

    private func makeSnapshot(mode: SegmentKind = .strength,
                              isPaused: Bool = false,
                              elapsedSeconds: Int = 600,
                              capturedAt: Date = Date(timeIntervalSince1970: 10000)) -> WorkoutSnapshot
    {
        WorkoutSnapshot(startedAt: Date(timeIntervalSince1970: 0),
                        mode: mode,
                        isPaused: isPaused,
                        elapsedSeconds: elapsedSeconds,
                        capturedAt: capturedAt)
    }
}
