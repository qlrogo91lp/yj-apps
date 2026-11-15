import SwiftUI

struct EndConfirmView: View {
    let onCancel: () -> Void
    let onEnd: () -> Void
    var body: some View {
        VStack(spacing: 8) {
            Text("술자리를 종료할까요?").font(.headline)
            Button("종료", action: onEnd).buttonStyle(.plain).frame(maxWidth: .infinity).padding(.vertical, 8)
                .foregroundStyle(BrandColor.danger).overlay(Capsule().stroke(BrandColor.danger))
            Button("계속 기록", action: onCancel).buttonStyle(.plain).font(.caption)
        }
    }
}

#Preview { EndConfirmView(onCancel: {}, onEnd: {}) }
