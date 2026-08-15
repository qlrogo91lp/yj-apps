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

    /// holePars/puttCounts는 holeScores와 같은 개수만 유효 — 아직 파가 없는 홀의 배열 길이 불일치를 자동으로 무시한다
    var relativeToPar: Int {
        zip(holeScores, holePars).reduce(0) { $0 + $1.0 - $1.1 }
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
