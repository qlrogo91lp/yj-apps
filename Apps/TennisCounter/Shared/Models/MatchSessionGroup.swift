import Foundation

/// 한 워크아웃(`workoutSessionId`)에 속한 경기들. 요약·기록 목록·캘린더 하단이 공유하는 표현 단위다.
/// 진행 중 경기 상태인 `MatchSession` 과 이름이 겹치지 않게 `~Group` 을 붙였다.
struct MatchSessionGroup: Identifiable {
    /// `workoutSessionId`. nil 기록은 각자 단독 세션이므로 경기의 `id` 를 쓴다.
    let id: UUID
    /// `startedAt` 오름차순.
    let matches: [Match]

    /// 세션 정렬 기준. 세션 안에서 가장 늦게 시작한 경기.
    var latestStartedAt: Date {
        matches.last?.startedAt ?? .distantPast
    }

    var date: Date {
        matches.first?.startedAt ?? .distantPast
    }

    /// 누적 지표는 그룹당 최댓값 하나. 같은 워크아웃의 경기들이 하나의 누적 축을 공유하므로
    /// 합산하면 같은 값을 여러 번 세게 된다.
    var elapsedSeconds: Int? {
        matches.compactMap(\.workoutElapsedSeconds).max()
    }

    var activeCalories: Double? {
        matches.compactMap(\.workoutCaloriesBurned).max()
    }

    static func group(_ matches: [Match]) -> [MatchSessionGroup] {
        var bySession: [UUID: [Match]] = [:]
        var solo: [MatchSessionGroup] = []

        for match in matches {
            if let sid = match.workoutSessionId {
                bySession[sid, default: []].append(match)
            } else {
                // 누적값 도입 이전 기록. 서로 묶을 근거가 없어 각자 한 세션으로 둔다.
                solo.append(MatchSessionGroup(id: match.id, matches: [match]))
            }
        }

        let grouped = bySession.map { sid, list in
            MatchSessionGroup(id: sid, matches: list.sorted { $0.startedAt < $1.startedAt })
        }
        return (grouped + solo).sorted { $0.latestStartedAt > $1.latestStartedAt }
    }
}
