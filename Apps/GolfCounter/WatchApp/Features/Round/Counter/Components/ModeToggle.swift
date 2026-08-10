import SwiftUI

struct ModeToggle: View {
    @Binding var mode: StrokeInputMode
    var height: CGFloat = 28

    var body: some View {
        HStack(spacing: 4) {
            segment(title: "스윙", value: .swing)
            segment(title: "퍼팅", value: .putt)
        }
    }

    private func segment(title: String, value: StrokeInputMode) -> some View {
        Button {
            mode = value
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: height)
        }
        .buttonStyle(.plain)
        .background(mode == value ? Color.green.opacity(0.8) : Color.gray.opacity(0.25), in: Capsule())
        .foregroundStyle(.white)
    }
}
