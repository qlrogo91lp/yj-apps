import Foundation
import SwiftData

extension ModelContext {
    /// 앱 저장소에서만 지운다 — 건강 앱의 워크아웃은 남는다 (기록 목록 플랜 "결정").
    /// 구간은 `deleteRule: .cascade` 로 함께 지워진다. 실패하면 되돌리고 false.
    ///
    /// 기록 탭과 홈이 같이 쓴다 — 두 곳에서 따로 지우면 실패 처리가 갈린다.
    @discardableResult
    func deleteRecord(_ record: WorkoutRecord) -> Bool {
        delete(record)
        do {
            try save()
            return true
        } catch {
            rollback()
            print("[HaruchiFit] 기록 삭제 실패 — \(error)")
            return false
        }
    }
}
