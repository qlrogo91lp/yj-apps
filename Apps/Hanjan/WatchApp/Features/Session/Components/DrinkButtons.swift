import SwiftUI

struct DrinkButtons: View {
    let canUndo: Bool
    let toastOnly: Bool
    let exceeded: Bool
    let onUndo: () -> Void
    let onDrink: () -> Void
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 5) {
                Button("취소", action: onUndo).buttonStyle(.plain).font(.caption.bold())
                    .frame(width: (geometry.size.width - 5) / 3, height: 48)
                    .background(.white.opacity(0.1), in: Capsule())
                    .opacity(canUndo ? 1 : 0.4).disabled(!canUndo)
                Button(toastOnly ? "짠만" : "한 잔", action: onDrink)
                    .buttonStyle(.plain).font(.caption.bold()).frame(maxWidth: .infinity).frame(height: 48)
                    .foregroundStyle(toastOnly ? BrandColor.amber : Color.black)
                    .background(toastOnly ? BrandColor.amber.opacity(0.2) : (exceeded ? BrandColor.danger : BrandColor.amber), in: Capsule())
            }
        }.frame(height: 48)
    }
}
