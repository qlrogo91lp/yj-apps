import SwiftUI

struct CountDisplay: View {
    let equivalent: Double
    let limit: Double
    let progress: ToastProgress?
    let exceeded: Bool
    var body: some View {
        HStack(alignment: .center, spacing: 5) {
            Text(SojuFormat.string(equivalent)).font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(exceeded ? BrandColor.danger : .primary)
            Text("/ \(SojuFormat.string(limit))잔").font(.caption).foregroundStyle(.secondary)
            if let progress {
                HStack(spacing: 2) {
                    ForEach(0 ..< progress.total, id: \.self) { index in
                        Circle().fill(index < progress.filled ? BrandColor.amber : BrandColor.amber.opacity(0.25)).frame(width: 5, height: 5)
                    }
                }.accessibilityLabel("\(progress.total)번 중 \(progress.filled)번째")
            }
        }.minimumScaleFactor(0.7).lineLimit(1)
    }
}

#Preview { CountDisplay(equivalent: 5, limit: 8, progress: ToastProgress(filled: 2, total: 3), exceeded: false) }
