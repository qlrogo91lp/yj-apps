import SwiftUI

struct AnnualComposition: View {
    let composition: StatisticsDashboard.Composition?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("운동 구성").font(.headline).foregroundStyle(HaruchiPalette.text)
            if let composition {
                GeometryReader { proxy in
                    HStack(spacing: 0) {
                        Rectangle().fill(HaruchiPalette.accent)
                            .frame(width: proxy.size.width * strengthRatio(for: composition))
                        Rectangle().fill(HaruchiPalette.cardio)
                            .frame(width: proxy.size.width * cardioRatio(for: composition))
                    }
                }
                .frame(height: 12)
                .clipShape(Capsule())
                HStack {
                    legend("근력 \(composition.strengthText) (\(composition.strengthPercent)%)", HaruchiPalette.accent)
                    Spacer()
                    legend("유산소 \(composition.cardioText) (\(composition.cardioPercent)%)", HaruchiPalette.cardio)
                }
            } else {
                Text("구성 시간이 있는 기록이 없어요")
                    .foregroundStyle(HaruchiPalette.dim)
            }
        }
        .padding()
        .background(HaruchiPalette.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func legend(_ text: String, _ color: Color) -> some View {
        Label { Text(text).font(.caption).foregroundStyle(HaruchiPalette.text) } icon: {
            Circle().fill(color).frame(width: 8, height: 8)
        }
    }

    private func strengthRatio(for composition: StatisticsDashboard.Composition) -> CGFloat {
        CGFloat(composition.strengthSeconds) / CGFloat(composition.strengthSeconds + composition.cardioSeconds)
    }

    private func cardioRatio(for composition: StatisticsDashboard.Composition) -> CGFloat {
        1 - strengthRatio(for: composition)
    }
}
