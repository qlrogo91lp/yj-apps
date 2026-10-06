import Foundation

/// 사용자가 붙이는 부위·메모 (제품 스펙 04 · D1 · D6). **HealthKit 에 자리가 없어 여기가 원본이다** —
/// 레코드를 갈아끼우는 경로는 반드시 `adoptAnnotations(from:)` 로 넘겨받아야 한다.
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

    /// 같은 워크아웃의 이전 레코드에서 부위·메모를 넘겨받는다.
    /// 워치 재전송은 레코드를 **지우고 새로 넣으므로**(`PersistenceService.upsert`) 이걸 거치지 않으면 사라진다.
    func adoptAnnotations(from old: WorkoutRecord) {
        bodyPartsRaw = old.bodyPartsRaw
        memo = old.memo
    }
}
