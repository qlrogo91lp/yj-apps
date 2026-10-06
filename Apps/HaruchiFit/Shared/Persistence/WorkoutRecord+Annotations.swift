import Foundation
import SwiftData

/// 사용자가 붙이는 부위·메모 (제품 스펙 04 · D1 · D6). **HealthKit 에 자리가 없어 여기가 원본이다** —
/// 워치 재전송은 객체를 교체하지 않고 `updateWorkoutData(from:in:)`로 운동 데이터만 갱신한다.
///
/// 저장(`save()`)은 하지 않는다. 호출부가 자기 컨텍스트에서 한다.
extension WorkoutRecord {
    /// 탭 = 토글 (D1). 고정 순서로 다시 쓰므로 모르는 값은 이때 사라진다.
    func toggle(_ part: BodyPart) {
        var selected = Set(bodyParts)
        if selected.contains(part) {
            selected.remove(part)
        } else {
            selected.insert(part)
        }
        bodyPartsRaw = BodyPart.allCases.filter(selected.contains).map(\.rawValue)
    }

    /// 앞뒤 공백을 자르고, 남는 게 없으면 메모가 없는 것으로 둔다 — 플레이스홀더가 다시 보여야 한다.
    func setMemo(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        memo = trimmed.isEmpty ? nil : trimmed
    }

    /// 워치가 같은 워크아웃을 다시 보내면 사용자 편집값은 남기고 운동 데이터만 제자리에서 갱신한다.
    /// 객체를 교체하지 않아 열려 있는 상세 시트와 목록이 같은 영속 ID를 계속 본다.
    func updateWorkoutData(from message: WorkoutRecordMessage, in context: ModelContext) {
        let replacedSegments = segments ?? []
        healthKitUUID = message.healthKitUUID
        startedAt = message.startedAt
        endedAt = message.endedAt
        totalSeconds = message.totalSeconds
        activeCalories = message.activeCalories
        totalCalories = message.totalCalories
        averageHeartRate = message.averageHeartRate
        source = .watch
        segments = message.segments.map {
            Segment(kind: $0.kind, startOffset: $0.startOffset, durationSeconds: $0.durationSeconds)
        }
        replacedSegments.forEach(context.delete)
    }
}
