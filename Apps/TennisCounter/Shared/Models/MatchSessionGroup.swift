import Foundation

/// 한 워크아웃(`workoutSessionId`)에 속한 경기들과 그 세션의 최종값.
/// 진행 중 경기 상태인 `MatchSession` 과 이름이 겹치지 않게 `~Group` 을 붙였다.
struct MatchSessionGroup: Identifiable {
    /// `workoutSessionId`. nil 기록은 각자 단독 세션이므로 경기의 `id` 를 쓴다.
    let id: UUID
    /// `startedAt` 오름차순. 경기 없이 운동만 한 세션은 빈 배열이다.
    let matches: [Match]
    /// 세션 레코드. 없으면(구버전 기록) 경기들의 최댓값으로 폴백한다.
    let record: WorkoutSessionRecord?

    var matchCount: Int {
        matches.count
    }

    var wins: Int {
        matches.count(where: { $0.myTotalSets > $0.yourTotalSets })
    }

    var losses: Int {
        matchCount - wins
    }

    /// 세션 정렬 기준. 레코드가 있으면 그 시작 시각, 없으면 마지막 경기의 시작.
    var latestStartedAt: Date {
        record?.startedAt ?? matches.last?.startedAt ?? .distantPast
    }

    var date: Date {
        record?.startedAt ?? matches.first?.startedAt ?? .distantPast
    }

    /// 누적 지표는 레코드가 우선. 폴백은 그룹당 최댓값 하나다 — 같은 워크아웃의 경기들이
    /// 하나의 누적 축을 공유하므로 합산하면 같은 값을 여러 번 세게 된다.
    var elapsedSeconds: Int? {
        record?.elapsedSeconds ?? matches.compactMap(\.workoutElapsedSeconds).max()
    }

    var activeCalories: Double? {
        record?.activeCalories ?? matches.compactMap(\.workoutCaloriesBurned).max()
    }

    var totalCalories: Double? {
        record?.totalCalories ?? matches.compactMap(\.workoutTotalCaloriesBurned).max()
    }

    /// **폴백하지 않는다.** `Match.averageHeartRate` 는 그 경기 구간의 평균이라
    /// 세션 평균이 아니다. 레코드가 없으면 보여줄 값이 없다.
    var averageHeartRate: Double? {
        record?.averageHeartRate
    }

    /// 화면이 보유한 경기와 레코드를 묶을 때, 아직 화면에 로드되지 않은 경기의 레코드를
    /// 빈 세션으로 오인하지 않도록 필요한 레코드만 고른다.
    static func recordsForGrouping(
        _ records: [WorkoutSessionRecord],
        displayedMatches: [Match],
        sourceMatches: [Match],
        includesMatchlessRecord: (WorkoutSessionRecord) -> Bool
    ) -> [WorkoutSessionRecord] {
        let displayedSessionIds = Set(displayedMatches.compactMap(\.workoutSessionId))
        let sourceSessionIds = Set(sourceMatches.compactMap(\.workoutSessionId))

        return records.filter { record in
            guard let sessionId = record.workoutSessionId else { return false }
            return displayedSessionIds.contains(sessionId)
                || (!sourceSessionIds.contains(sessionId) && includesMatchlessRecord(record))
        }
    }

    static func group(_ matches: [Match],
                      records: [WorkoutSessionRecord] = []) -> [MatchSessionGroup]
    {
        var recordsBySession: [UUID: WorkoutSessionRecord] = [:]
        for record in records {
            if let sid = record.workoutSessionId { recordsBySession[sid] = record }
        }

        var bySession: [UUID: [Match]] = [:]
        var solo: [MatchSessionGroup] = []

        for match in matches {
            if let sid = match.workoutSessionId {
                bySession[sid, default: []].append(match)
            } else {
                // 누적값 도입 이전 기록. 서로 묶을 근거가 없어 각자 한 세션으로 둔다.
                solo.append(MatchSessionGroup(id: match.id, matches: [match], record: nil))
            }
        }

        let grouped = bySession.map { sid, list in
            MatchSessionGroup(id: sid,
                              matches: list.sorted { $0.startedAt < $1.startedAt },
                              record: recordsBySession[sid])
        }

        // 경기를 한 판도 저장하지 않고 운동만 한 세션.
        let empty = recordsBySession
            .filter { bySession[$0.key] == nil }
            .map { sid, record in MatchSessionGroup(id: sid, matches: [], record: record) }

        return (grouped + solo + empty).sorted { $0.latestStartedAt > $1.latestStartedAt }
    }
}
