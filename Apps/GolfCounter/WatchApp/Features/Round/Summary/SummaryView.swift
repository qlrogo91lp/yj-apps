import SwiftUI

/// 종료 요약 — 총타수(주인공) · 오버파 배지 · 홀/퍼트 · 저장/버리기 (spec 2026-08-17 개정).
///
/// 총타수·오버파·퍼트는 **트림 후** 기준이다. 워크아웃 메트릭은 여기 띄우지 않고 전송
/// 페이로드에만 싣는다 — iOS 상세 화면이 같은 정보를 보여준다.
struct SummaryView: View {
    @ObservedObject var viewModel: RoundViewModel

    /// 폐기는 되돌릴 수 없다(스냅샷까지 지운다) — 확인을 한 번 받는다.
    @State private var isConfirmingDiscard = false

    var body: some View {
        VStack(spacing: 4) {
            Spacer()

            if viewModel.recordedHoleCount > 0 {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(viewModel.trimmedTotalStrokes)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                    Text(ScoreFormat.relativeToPar(viewModel.trimmedRelativeToPar))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Text(String(format: String(localized: "summary_holes_putts"),
                            viewModel.recordedHoleCount,
                            viewModel.trimmedTotalPutts))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                Text(String(localized: "summary_holes_empty"))
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            buttons
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

    /// 0홀·전송 중에는 저장 버튼 하나가 전폭을 차지한다. 그 외에는 버리기/저장 가로 2등분.
    @ViewBuilder
    private var buttons: some View {
        if viewModel.recordedHoleCount == 0 {
            primaryButton(label: String(localized: "round_end_confirm_empty"))
        } else if viewModel.isTransmitting {
            primaryButton(label: String(localized: "summary_transmitting"))
        } else {
            HStack(spacing: 8) {
                Button(action: { isConfirmingDiscard = true }) {
                    Text(String(localized: "summary_discard_button"))
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 38)
                }
                .buttonStyle(.bordered)

                Button(action: viewModel.saveAndTransmit) {
                    Text(String(localized: "summary_save"))
                        .font(.system(size: 15, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 38)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
    }

    private func primaryButton(label: String) -> some View {
        Button(action: viewModel.saveAndTransmit) {
            Text(label)
                .font(.system(size: 15, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 38)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
    }
}

#Preview {
    let viewModel = RoundViewModel()
    viewModel.selectPar(4)
    viewModel.incrementStroke()
    viewModel.finishRound()
    return SummaryView(viewModel: viewModel)
}
