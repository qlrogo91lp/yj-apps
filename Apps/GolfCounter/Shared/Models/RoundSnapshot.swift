import Foundation

/// 라운드 진행 중 상태 스냅샷.
/// 워치 크래시/강제종료 복구와 컴플리케이션 표시 데이터원을 겸한다 (spec §3).
struct RoundSnapshot: Equatable {
    /// 라운드 시작 시 생성해 복구를 넘어 유지한다. iOS가 이 값으로 중복 수신을 거른다.
    ///
    /// 기본값이 있어 멤버와이즈 init에서 생략할 수 있지만, 생략하면 **호출할 때마다 새 UUID가
    /// 생긴다.** `RoundViewModel.snapshot`처럼 라운드 정체성을 실어야 하는 자리는 반드시 명시한다.
    var id = UUID()
    /// 선택한 홀 수 상한 (9 또는 18).
    var holeCount: Int = 18
    var startedAt: Date
    var courseName: String?
    var currentHoleIndex: Int // 0-based, 인덱스 = 홀 번호 - 1
    var holeScores: [Int]
    var holePars: [Int]
    var puttCounts: [Int]

    var currentHoleNumber: Int {
        currentHoleIndex + 1
    }

    var totalStrokes: Int {
        holeScores.reduce(0, +)
    }

    var totalPutts: Int {
        puttCounts.reduce(0, +)
    }

    /// 집계 대상 홀(파와 타수가 모두 있는 홀)만 더한다. 규칙은 `ScoreAggregate` 참조 (spec §3).
    var relativeToPar: Int {
        ScoreAggregate.relativeToPar(holeScores: holeScores, holePars: holePars)
    }
}

extension RoundSnapshot {
    /// 전송 직전, 배열 말단에서부터 `par == 0`인 미기록 홀을 제거한다 (spec §2 결정 2).
    ///
    /// `par == 0`이면 파 선택 화면이 떠 카운터에 접근할 수 없으므로 `score`·`putts`도 반드시
    /// 0이다 — 이 트림은 무손실이다. 중간에 낀 `par == 0` 홀은 건드리지 않는다(사용자가
    /// 의도적으로 건너뛴 홀일 수 있다).
    func trimmed() -> RoundSnapshot {
        var end = holePars.count
        while end > 0, holePars[end - 1] == 0 {
            end -= 1
        }

        var copy = self
        copy.holeScores = Array(holeScores.prefix(end))
        copy.holePars = Array(holePars.prefix(end))
        copy.puttCounts = Array(puttCounts.prefix(end))
        copy.currentHoleIndex = max(0, min(currentHoleIndex, end - 1))
        return copy
    }

    /// 파가 기록된 홀 수 = 유효 홀의 개수 (spec §3). 종료 확인 문구와 요약 헤더가 쓴다.
    ///
    /// 건너뛴 홀(`par == 0`)은 배열 **중간**에 남아 있어도 세지 않는다 —
    /// `GolfRound.recordedHoleCount`와 같은 규칙이라 워치 요약과 iOS 기록 뱃지가 같은 수를 보인다.
    /// 말단 0은 `filter`가 알아서 걸러내므로 `trimmed()`를 거칠 필요가 없다.
    var recordedHoleCount: Int {
        holePars.filter { $0 > 0 }.count
    }
}

/// Codable을 확장에 두는 이유: 본문에 init을 선언하면 멤버와이즈 init이 사라져
/// 기존 생성 호출부 10곳이 전부 깨진다.
extension RoundSnapshot: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, holeCount, startedAt, courseName, currentHoleIndex, holeScores, holePars, puttCounts
    }

    /// `id`·`holeCount`가 없던 구버전 스냅샷도 살려낸다 (spec §3.5).
    /// `RoundSnapshotStore.load()`가 `try?`로 디코딩하므로 여기서 던지면
    /// 진행 중 라운드가 조용히 사라진다.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        courseName = try container.decodeIfPresent(String.self, forKey: .courseName)
        currentHoleIndex = try container.decode(Int.self, forKey: .currentHoleIndex)
        holeScores = try container.decode([Int].self, forKey: .holeScores)
        holePars = try container.decode([Int].self, forKey: .holePars)
        puttCounts = try container.decode([Int].self, forKey: .puttCounts)

        // 스냅샷에 남아 있다는 것은 아직 전송되지 않았다는 뜻이므로(전송 성공 시 스냅샷을 지운다)
        // 새 id를 발급해도 iOS에 중복이 생기지 않는다.
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()

        // 상한이 없던 시절 라운드는 18홀을 넘겼을 수 있다. 그냥 18로 채우면 currentHoleIndex가
        // 상한 밖에 놓여 이미 친 홀이 잘린다 — 실제 기록 길이를 하한으로 잡는다.
        holeCount = try container.decodeIfPresent(Int.self, forKey: .holeCount) ?? max(18, holeScores.count)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(holeCount, forKey: .holeCount)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(courseName, forKey: .courseName)
        try container.encode(currentHoleIndex, forKey: .currentHoleIndex)
        try container.encode(holeScores, forKey: .holeScores)
        try container.encode(holePars, forKey: .holePars)
        try container.encode(puttCounts, forKey: .puttCounts)
    }
}
