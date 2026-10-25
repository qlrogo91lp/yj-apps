import Foundation
import SwiftData

extension ModelContext {
    /// 워치가 보낸 기록을 저장한다. 폰이 메시지를 받는 즉시 부르며, 화면과 무관하다.
    ///
    /// CloudKit 이 `.unique` 를 막으므로 **중복 방지는 여기 책임이다** (아키텍처 3절).
    /// `healthKitUUID` 가 있으면 그 키로 기존 기록을 찾아 제자리에서 갱신하고(부위·메모·영속 ID 유지),
    /// 없으면 그냥 추가한다 — 키가 없는 기록끼리는 구분할 방법이 없어 중복 검사를 걸 수 없다.
    /// 큐 배달이 늦으면 건강 앱 import 가 같은 UUID 의 근력 기록을 먼저 만들 수 있는데, 이 경우도
    /// 제자리 갱신이 워치 기록으로 바로잡는다.
    ///
    /// 실패하면 던진다. `rollback()` 은 알림과 묶여 있어 호출부가 한다.
    func saveWatchRecord(_ message: WorkoutRecordMessage) throws {
        if let uuid = message.healthKitUUID {
            let matching = FetchDescriptor<WorkoutRecord>(predicate: #Predicate { $0.healthKitUUID == uuid })
            // 열린 상세 시트가 이 객체를 잡고 있으므로 지우고 새로 넣으면 안 된다.
            if let existing = try fetch(matching).first {
                existing.updateWorkoutData(from: message, in: self)
                try save()
                return
            }
        }
        let record = WorkoutRecord(healthKitUUID: message.healthKitUUID,
                                   startedAt: message.startedAt,
                                   endedAt: message.endedAt,
                                   totalSeconds: message.totalSeconds,
                                   activeCalories: message.activeCalories,
                                   totalCalories: message.totalCalories,
                                   averageHeartRate: message.averageHeartRate,
                                   source: .watch)
        record.segments = message.segments.map {
            Segment(kind: $0.kind, startOffset: $0.startOffset, durationSeconds: $0.durationSeconds)
        }
        insert(record)
        try save()
    }
}
