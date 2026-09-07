import SwiftUI

/// W2 — 세션이 끝난 뒤 **저장할지 버릴지** 정하는 화면.
///
/// 버튼 배치·크기는 GolfCounter 의 요약 화면을 따른다 (`.bordered` + `.borderedProminent`,
/// 가로 2등분). 시리즈 일관성이 목적이고 틴트만 그린 → 오렌지로 바꾼다.
struct SummaryView: View {
    @ObservedObject var viewModel: WorkoutViewModel

    /// 버리면 되돌릴 수 없다 (HealthKit 에서도 지운다) — 확인을 한 번 받는다.
    @State private var isConfirmingDiscard = false

    var body: some View {
        VStack(spacing: 6) {
            Text("운동 완료")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.brandOrange)

            Text(SummaryFormat.duration(record?.totalSeconds ?? 0))
                .font(.system(size: 34, weight: .bold, design: .rounded))

            if let segments = record?.segments, !segments.isEmpty {
                SegmentBar(segments: segments)
                    .padding(.horizontal, 4)
                kindTotals(of: segments)
            }

            metrics

            Spacer(minLength: 4)

            buttons
        }
        .padding(.horizontal, 8)
        .confirmationDialog("이 기록을 버릴까요?",
                            isPresented: $isConfirmingDiscard,
                            titleVisibility: .visible)
        {
            Button("버리기", role: .destructive) { viewModel.discard() }
            Button("취소", role: .cancel) {}
        }
    }

    private var record: WorkoutRecordMessage? {
        viewModel.pendingRecord
    }

    /// 배경 카드 없이 텍스트만 — 기존 화면의 밀도를 유지한다.
    private func kindTotals(of segments: [WorkoutRecordMessage.SegmentPayload]) -> some View {
        HStack(spacing: 10) {
            ForEach(SegmentKind.allCases, id: \.self) { kind in
                let seconds = segments.filter { $0.kind == kind }.reduce(0) { $0 + $1.durationSeconds }
                if seconds > 0 {
                    Text("\(kind.title) \(seconds / 60)분")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var metrics: some View {
        HStack(spacing: 12) {
            if let heartRate = record?.averageHeartRate, heartRate > 0 {
                Label("\(Int(heartRate))", systemImage: "heart.fill")
                    .foregroundStyle(.red)
            }
            Label("\(Int(record?.activeCalories ?? 0))", systemImage: "flame.fill")
                .foregroundStyle(Color.brandOrange)
        }
        .font(.system(size: 13))
        .labelStyle(.titleAndIcon)
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            Button { isConfirmingDiscard = true } label: {
                Text("버리기")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 38)
            }
            .buttonStyle(.bordered)

            Button { viewModel.save() } label: {
                Text("저장")
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 38)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brandOrange)
        }
    }
}
