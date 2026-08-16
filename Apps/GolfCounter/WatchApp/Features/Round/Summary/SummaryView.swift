import SwiftUI

/// 종료 요약 — 기록 홀 수 · 오버파 · 총타수/총퍼트 · 저장&전송 (spec §3.3).
///
/// 표시값은 전부 **트림 후** 기준이다. 상단의 "N홀 완료"가 실제로 전송될 홀 수를
/// 발신 직전에 다시 확인시킨다.
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

            Text("\(viewModel.trimmedTotalStrokes)타 · \(viewModel.trimmedTotalPutts)퍼트")
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
                Button("저장 안 함") { isConfirmingDiscard = true }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .disabled(viewModel.isTransmitting)
            }
        }
        .padding(.horizontal, 8)
        .confirmationDialog("이 라운드를 저장하지 않고 버릴까요?",
                            isPresented: $isConfirmingDiscard,
                            titleVisibility: .visible)
        {
            Button("버리기", role: .destructive, action: viewModel.discardRound)
            Button("취소", role: .cancel) {}
        }
    }

    private var headline: String {
        viewModel.recordedHoleCount > 0
            ? "\(viewModel.recordedHoleCount)홀 완료"
            : "기록된 홀 없음"
    }

    /// 메트릭 대기 중에도 버튼은 살아 있다 — 문구만 바뀐다 (spec §2 결정 9).
    private var buttonLabel: String {
        if viewModel.isTransmitting { return "전송 중…" }
        return viewModel.recordedHoleCount > 0 ? "저장 & 전송" : "저장 없이 종료"
    }
}

#Preview {
    let viewModel = RoundViewModel()
    viewModel.selectPar(4)
    viewModel.incrementStroke()
    viewModel.finishRound()
    return SummaryView(viewModel: viewModel)
}
