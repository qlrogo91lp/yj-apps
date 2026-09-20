import Foundation

/// `WorkoutRecord` 들을 **날짜 한 칸씩으로 접는다.** 홈 잔디·기록 달력·통계 연 잔디가
/// 같은 결과를 나눠 쓴다 — 화면부터 만들면 셋이 각자 계산하게 되고, 규칙이 갈린 뒤에
/// 합치는 건 훨씬 비싸다 (스펙 "왜 화면보다 먼저인가").
///
/// **필터를 갖지 않는다.** 들어온 건 다 센다. D-M5 의 "근력·유산소로 분류되는 워크아웃만
/// 반영" 은 #2 HealthKit import 가 매핑 표로 **입구에서** 지킨다 — 두 곳에서 거르면
/// 규칙이 갈린다 (스펙 4.5).
enum GrassAggregator {
    /// 하루의 경계는 **시작 시각**이다 (스펙 4.1). 23:40 에 시작해 00:30 에 끝난 세션은
    /// 전부 시작한 날 칸에 들어간다.
    ///
    /// 타임존은 호출부가 준 `calendar` 를 따른다. 앱은 `.current` 를 쓰므로 해외에 나가면
    /// 과거 칸이 한 칸 움직여 보일 수 있다 — 기록 시점의 타임존을 저장하는 대안은 모델에
    /// 필드를 늘리는 값에 비해 얻는 게 없다. v1 은 이대로 간다 (스펙 4.1).
    ///
    /// 결과는 날짜 오름차순이고, **레코드가 없는 날은 아예 들어 있지 않다** (0단계).
    static func fold(_ records: [WorkoutRecord],
                     calendar: Calendar = .current) -> [DailyAggregate]
    {
        var buckets: [Date: Bucket] = [:]
        for record in records {
            let day = calendar.startOfDay(for: record.startedAt)
            buckets[day, default: Bucket()].add(record)
        }
        return buckets
            .map { $0.value.aggregate(on: $0.key) }
            .sorted { $0.day < $1.day }
    }

    /// 한 칸이 쌓이는 동안의 중간 상태. **한 번의 순회로 다섯 값을 전부 낸다.**
    private struct Bucket {
        var totalSeconds = 0
        var strengthSeconds = 0
        var cardioSeconds = 0
        var calories: Double?
        var sessionCount = 0

        mutating func add(_ record: WorkoutRecord) {
            totalSeconds += record.totalSeconds
            sessionCount += 1

            for segment in record.orderedSegments {
                switch segment.kind {
                case .strength: strengthSeconds += segment.durationSeconds
                case .cardio: cardioSeconds += segment.durationSeconds
                }
            }

            // 값을 가진 레코드가 하나도 없으면 nil 로 남는다 — 칼로리 기준으로 전환했을 때
            // 그 날이 최소 농도로 떨어져야 하기 때문이다 (스펙 4.4).
            if let value = record.totalCalories {
                calories = (calories ?? 0) + value
            }
        }

        func aggregate(on day: Date) -> DailyAggregate {
            DailyAggregate(day: day,
                           totalSeconds: totalSeconds,
                           strengthSeconds: strengthSeconds,
                           cardioSeconds: cardioSeconds,
                           totalCalories: calories,
                           sessionCount: sessionCount)
        }
    }
}
