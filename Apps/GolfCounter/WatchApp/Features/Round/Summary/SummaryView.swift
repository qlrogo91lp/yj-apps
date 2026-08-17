import SwiftUI

/// 종료 요약 — 기록 홀 수 · 오버파 · 총타수/총퍼트 · 저장&전송 (spec §3.3).
///
/// 오버파·타수·퍼트는 **트림 후** 기준이지만 상단의 "N홀 완료"는 집계 대상 홀 개수라
/// 다를 수 있다 (`RoundViewModel.recordedHoleCount` 참고). 워크아웃 메트릭은 여기 띄우지
/// 않고 전송 페이로드에만 싣는다 — iOS 상세 화면이 같은 정보를 보여준다.
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
                // 전송 중 숨기는 이유는 순전히 화면 혼선 방지다 — 전송은 원자적이고
                // 대기 중이던 전송도 isTransmitting = false로 취소된다.
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
