import SwiftUI

struct DrinkButtons: View {
    let canUndo: Bool
    let toastOnly: Bool
    let exceeded: Bool
    let onUndo: () -> Void
    let onDrink: () -> Void
    var body: some View {
        HStack {
            Button("취소", action: onUndo).buttonStyle(.plain).frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color.primary.opacity(0.1), in: Capsule()).overlay(Capsule().stroke(Color.primary.opacity(0.2)))
                .disabled(!canUndo).opacity(canUndo ? 1 : 0.4)
            if toastOnly {
                Button("짠만", action: onDrink).buttonStyle(.plain).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .foregroundStyle(BrandColor.amber).overlay(Capsule().stroke(BrandColor.amber))
            } else {
                Button("한 잔", action: onDrink).frame(maxWidth: .infinity).padding(.vertical, 6)
                    .buttonStyle(.borderedProminent).tint(exceeded ? BrandColor.danger : BrandColor.amber).foregroundStyle(.black)
            }
        }
    }
}

#Preview { DrinkButtons(canUndo: true, toastOnly: false, exceeded: false, onUndo: {}, onDrink: {}) }
