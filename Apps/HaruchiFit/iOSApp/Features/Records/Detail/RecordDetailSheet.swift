import SwiftData
import SwiftUI

/// 기록 상세 시트를 띄우는 배선 — 기록 탭과 홈이 같은 코드를 탄다.
///
/// 규칙은 기록 상세 플랜의 Review Focus 그대로다.
/// - **삭제는 시트가 완전히 내려간 뒤에 한다.** 떠 있는 시트가 지워진 모델을 읽으면 크래시한다
/// - 닫힐 때 메모 저장이 실패하면 초안을 보관했다가 같은 기록을 다시 열 때 돌려준다
/// - 시트가 닫히면(삭제 제외) `onFinish` 로 호출한 화면이 목록을 다시 만든다 — `@Query` 는 모델 **동일성**으로
///   비교해 속성 변경(부위·메모)에 반응하지 않는다
private struct RecordDetailSheetModifier: ViewModifier {
    @Binding var item: WorkoutRecord?
    let onFinish: () -> Void
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var alerts: AppAlertCenter
    @State private var deleteAfterDismiss: WorkoutRecord?
    @State private var editAfterDismiss: WorkoutRecord?
    @State private var editing: WorkoutRecord?
    @State private var memoDrafts: [PersistentIdentifier: String] = [:]

    func body(content: Content) -> some View {
        content.sheet(item: $item, onDismiss: finish) { record in
            RecordDetailView(
                record: record,
                context: modelContext,
                initialMemoDraft: memoDrafts[record.persistentModelID],
                onDismissCommit: { draft in
                    if let draft {
                        memoDrafts[record.persistentModelID] = draft
                        alerts.report(.editFailed)
                    } else {
                        memoDrafts[record.persistentModelID] = nil
                    }
                },
                onDelete: {
                    deleteAfterDismiss = record
                    item = nil
                },
                onEdit: {
                    editAfterDismiss = record
                    item = nil
                }
            )
        }.sheet(item: $editing) { record in
            ManualRecordView(record: record, initialMemoDraft: memoDrafts[record.persistentModelID]) {
                memoDrafts[record.persistentModelID] = nil
                onFinish()
            }
        }
    }

    private func finish() {
        if let record = deleteAfterDismiss {
            deleteAfterDismiss = nil
            memoDrafts[record.persistentModelID] = nil
            // 지운 직후에는 `onFinish` 를 부르지 않는다 — 호출한 화면이 아직 지워진 모델이 든 `@Query` 결과를
            // 읽으면 크래시한다. 삭제는 `@Query` 변경이 알아서 화면을 다시 만든다.
            if !modelContext.deleteRecord(record) { alerts.report(.deleteFailed) }
        } else if let record = editAfterDismiss {
            editAfterDismiss = nil
            onFinish()
            editing = record
        } else {
            onFinish()
        }
    }
}

extension View {
    /// `item` 에 기록을 넣으면 상세 시트가 열린다. 시트가 닫힌 뒤 `onFinish` 를 부른다 — 삭제로 닫힌 때는 부르지 않는다.
    func recordDetailSheet(item: Binding<WorkoutRecord?>, onFinish: @escaping () -> Void) -> some View {
        modifier(RecordDetailSheetModifier(item: item, onFinish: onFinish))
    }
}
