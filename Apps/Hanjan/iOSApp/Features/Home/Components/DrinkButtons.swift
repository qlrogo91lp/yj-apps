import SwiftUI

struct DrinkButtons: View {
    let canUndo: Bool
    let toastOnly: Bool
    let exceeded: Bool
    let onUndo: () -> Void
    let onDrink: () -> Void
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 8) {
                CapsuleButton(title: "취소", isEnabled: canUndo, height: 56, action: onUndo)
                    .frame(width: (geometry.size.width - 8) / 4, height: 56)
                PrimaryButton(title: toastOnly ? "짠만" : "한 잔", isDanger: exceeded, isToast: toastOnly, height: 56, action: onDrink)
            }
        }.frame(height: 56)
    }
}

#Preview { DrinkButtons(canUndo: true, toastOnly: false, exceeded: false, onUndo: {}, onDrink: {}) }
