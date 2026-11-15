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
                Button("취소", action: onUndo).buttonStyle(.plain).font(.caption.bold()).frame(width: (geometry.size.width - 5) * 0.25, height: 38)
                    .background(.white.opacity(0.1), in: Capsule()).overlay(Capsule().stroke(.white.opacity(0.2)))
                    .opacity(canUndo ? 1 : 0.4).disabled(!canUndo)
                if toastOnly {
                    Button("짠만", action: onDrink).buttonStyle(.plain).font(.caption.bold()).frame(maxWidth: .infinity).frame(height: 38)
                        .foregroundStyle(BrandColor.amber).overlay(Capsule().stroke(BrandColor.amber))
                } else {
                    Button("한 잔", action: onDrink).font(.caption.bold()).frame(maxWidth: .infinity).frame(height: 38)
                        .buttonStyle(.borderedProminent).tint(exceeded ? BrandColor.danger : BrandColor.amber).foregroundStyle(.black)
                }
            }
        }.frame(height: 38)
    }
}

#Preview { DrinkButtons(canUndo: true, toastOnly: false, exceeded: false, onUndo: {}, onDrink: {}) }
