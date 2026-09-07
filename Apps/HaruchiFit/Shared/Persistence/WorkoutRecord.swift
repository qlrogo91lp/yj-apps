import Foundation
import SwiftData

/// 워크아웃 한 건. **세그먼트의 원본은 여기다** — HealthKit 은 근력↔유산소처럼 카테고리가
/// 다른 구간 전환을 거부하므로(아키텍처 2절 · D-M8), 구간을 남길 곳이 여기밖에 없다.
///
/// CloudKit 제약상 **모든 속성이 optional 이거나 기본값을 갖는다** (PersistenceCore README).
@Model
final class WorkoutRecord {
    /// HealthKit 워크아웃과의 연결 키이자 중복 저장 방지 키.
    /// CloudKit 이 `.unique` 를 막으므로 **중복 검사는 앱 코드 책임**이다 — 저장 시 이 값으로
    /// predicate 를 걸어 upsert 한다. 수동 기록은 nil 이다.
    var healthKitUUID: UUID?

    var startedAt: Date = Date()
    var endedAt: Date?
    /// 워크아웃 전체 시간(초). 세그먼트 시간의 합과 반올림 오차만큼 다를 수 있다.
    var totalSeconds: Int = 0

    var activeCalories: Double?
    /// 활동 + 휴식. 화면에 넘기는 값은 워크아웃 누적값이다 (CLAUDE.md 워크아웃 동작 계약).
    var totalCalories: Double?
    var averageHeartRate: Double?

    /// 순서 있는 구간. `startOffset` 오름차순으로 읽는다 — SwiftData 관계는 순서를 보장하지 않는다.
    /// CloudKit 요구사항: optional + inverse 명시.
    @Relationship(deleteRule: .cascade, inverse: \Segment.record) var segments: [Segment]?

    var memo: String?

    /// `WorkoutSource` 의 rawValue. enum 을 직접 저장하지 않는 것은 Tennis `Match.mode` 와 같은 이유다.
    var sourceRaw: String = WorkoutSource.watch.rawValue

    var source: WorkoutSource {
        get { WorkoutSource(rawValue: sourceRaw) ?? .watch }
        set { sourceRaw = newValue.rawValue }
    }

    /// 시작 오프셋 순으로 정렬된 구간. 화면은 항상 이쪽을 쓴다.
    var orderedSegments: [Segment] {
        (segments ?? []).sorted { $0.startOffset < $1.startOffset }
    }

    init(healthKitUUID: UUID? = nil,
         startedAt: Date = Date(),
         endedAt: Date? = nil,
         totalSeconds: Int = 0,
         activeCalories: Double? = nil,
         totalCalories: Double? = nil,
         averageHeartRate: Double? = nil,
         memo: String? = nil,
         source: WorkoutSource = .watch)
    {
        self.healthKitUUID = healthKitUUID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.totalSeconds = totalSeconds
        self.activeCalories = activeCalories
        self.totalCalories = totalCalories
        self.averageHeartRate = averageHeartRate
        self.memo = memo
        sourceRaw = source.rawValue
    }
}

/// 이 기록이 어디서 왔는지. 잔디 농도가 수동 기록을 최소 농도로 떨어뜨릴 때 쓴다 (제품 스펙 D4).
enum WorkoutSource: String, Codable, CaseIterable {
    case watch
    case healthKitImport
    case manual
}
