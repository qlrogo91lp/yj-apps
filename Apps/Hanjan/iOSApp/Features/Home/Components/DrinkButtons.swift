import SwiftUI

struct DrinkButtons: View {
    let canUndo: Bool
    let toastOnly: Bool
    let exceeded: Bool
    let onUndo: () -> Void
    let onDrink: () -> Void
    var body: some View {
        HStack {
            CapsuleButton(title: "취소", isEnabled: canUndo, action: onUndo)
            if toastOnly {
                CapsuleButton(title: "짠만", style: .toast, action: onDrink)
            } else {
                PrimaryButton(title: "한 잔", isDanger: exceeded, action: onDrink)
            }
        }
    }
}

#Preview { DrinkButtons(canUndo: true, toastOnly: false, exceeded: false, onUndo: {}, onDrink: {}) }
