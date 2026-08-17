import SwiftUI

/// 종료 요약 — 기록 홀 수 · 오버파 · 총타수/총퍼트 · 저장&전송 (spec §3.3).
///
/// 오버파·타수·퍼트는 **트림 후** 기준이다. 상단의 "N홀 완료"는 다르다 — 집계 대상 홀(파와
/// 타수가 모두 있는 홀) 개수라 iOS 기록 뱃지와 같은 수를 보이지만, 중간에 건너뛴 홀이 있으면
/// 트림 후 전송 배열 길이보다 작을 수 있다 (`RoundViewModel.recordedHoleCount` 참고).
///
/// 워크아웃 메트릭(칼로리·심박·거리·시간)은 여기 띄우지 않고 전송 페이로드에만 싣는다 —
/// `stopWorkout()`이 1~3초 걸려 대기·도착·미도착 세 상태를 설계해야 하는데, 같은 정보를
/// iOS 상세 화면이 보여줄 예정이라 값에 비해 비용이 크다.
struct SummaryView: View {
    @ObservedObject var viewModel: RoundViewModel

    /// 폐기는 되돌릴 수 없다(스냅샷까지 지운다) — 확인을 한 번 받는다.
    @State private var isConfirmingDiscard = false

    var body: some View {
        VStack(spacing: 4) {
            Spacer()

            Text(headline)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text(ScoreFormat.relativeToPar(viewModel.trimmedRelativeToPar))
                .font(.system(size: 42, weight: .bold, design: .rounded))

            Text(String(format: String(localized: "summary_strokes_putts"),
                        viewModel.trimmedTotalStrokes,
                        viewModel.trimmedTotalPutts))
                .font(.system(size: 15))
                .foregroundStyle(.secondary)

            if let courseName = viewModel.courseName {
                Text(courseName)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: viewModel.saveAndTransmit) {
                Text(buttonLabel)
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 38)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

            if viewModel.recordedHoleCount > 0 {
                // 전송 자체는 원자적이라 절반만 도착한 라운드가 남을 위험은 없다 —
                // isTransmitting = false로 대기 중이던 전송도 취소된다. 여기서 막는 이유는
                // 순전히 화면 혼선: "전송 중…"과 "저장 안 함"이 동시에 떠 있는 걸 피한다.
                Button(String(localized: "summary_discard_button")) { isConfirmingDiscard = true }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .disabled(viewModel.isTransmitting)
            }
        }
        .padding(.horizontal, 8)
        .confirmationDialog(String(localized: "summary_discard_title"),
                            isPresented: $isConfirmingDiscard,
                            titleVisibility: .visible)
        {
            Button(String(localized: "summary_discard_confirm"), role: .destructive, action: viewModel.discardRound)
            Button(String(localized: "common_cancel"), role: .cancel) {}
        }
    }

    private var headline: String {
        viewModel.recordedHoleCount > 0
            ? String(format: String(localized: "summary_holes_completed"), viewModel.recordedHoleCount)
            : String(localized: "summary_holes_empty")
    }

    /// 메트릭 대기 중에도 버튼은 살아 있다 — 문구만 바뀐다 (spec §2 결정 9).
    private var buttonLabel: String {
        if viewModel.isTransmitting { return String(localized: "summary_transmitting") }
        return viewModel.recordedHoleCount > 0
            ? String(localized: "summary_save_send")
            : String(localized: "round_end_confirm_empty")
    }
}

#Preview {
    let viewModel = RoundViewModel()
    viewModel.selectPar(4)
    viewModel.incrementStroke()
    viewModel.finishRound()
    return SummaryView(viewModel: viewModel)
}
