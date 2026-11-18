import AppIntents
import SwiftUI

struct LockScreenView: View {
    let state: HanjanActivityAttributes.ContentState
    private var color: Color {
        LimitLevel.of(equivalent: state.equivalent, limit: state.limit) == .exceeded ? BrandColor.danger : BrandColor.amber
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("한잔 · \(state.kindName)").font(.headline)
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(SojuFormat.string(state.equivalent)) / \(SojuFormat.string(state.limit))잔").font(.title2.bold()).foregroundStyle(color)
                    if let filled = state.toastFilled, let total = state.toastTotal {
                        HStack(spacing: 8) {
                            ForEach(0 ..< total, id: \.self) { index in
                                Circle().fill(index < filled ? BrandColor.amber : BrandColor.amber.opacity(0.2)).frame(width: 10, height: 10)
                            }
                        }.accessibilityLabel("\(total)번 중 \(filled)번째")
                    }
                }
                Spacer()
                Button(intent: AddDrinkIntent()) {
                    Text(state.toastOnly ? "짠만" : "한 잔").font(.headline).frame(width: 64, height: 38)
                }
                .buttonStyle(.plain)
                .foregroundStyle(state.toastOnly ? BrandColor.amber : Color.black)
                .background(state.toastOnly ? BrandColor.amber.opacity(0.2) : color, in: Capsule())
            }
            ProgressView(value: min(state.equivalent / max(state.limit, 1), 1)).tint(color)
        }.padding()
    }
}

#Preview { LockScreenView(state: .init(kindName: "소주", equivalent: 5, limit: 8, toastFilled: 1, toastTotal: 3, toastOnly: true)) }
