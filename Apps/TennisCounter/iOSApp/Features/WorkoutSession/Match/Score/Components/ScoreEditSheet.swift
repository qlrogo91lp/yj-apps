import SwiftUI

struct ScoreEditSheet: View {
    let myScore: String
    let yourScore: String
    let onEdit: (PlayerSide, Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text(String(localized: "score_edit_title"))
                .font(.headline)
                .padding(.top, 8)

            HStack(spacing: 32) {
                stepperGroup(
                    label: String(localized: "watch_score_me"),
                    color: .green,
                    displayScore: myScore,
                    onMinus: { onEdit(.me, false) },
                    onPlus: { onEdit(.me, true) }
                )
                stepperGroup(
                    label: String(localized: "watch_score_opp"),
                    color: .orange,
                    displayScore: yourScore,
                    onMinus: { onEdit(.opponent, false) },
                    onPlus: { onEdit(.opponent, true) }
                )
            }
            .padding(.horizontal, 32)

            Button(String(localized: "btn_confirm")) { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 8)
        }
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.visible)
    }

    private func stepperGroup(
        label: String,
        color: Color,
        displayScore: String,
        onMinus: @escaping () -> Void,
        onPlus: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 10) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
            HStack(spacing: 16) {
                Button(action: onMinus) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(color.opacity(0.7))
                }
                Text(displayScore)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(color)
                    .frame(minWidth: 44)
                Button(action: onPlus) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(color.opacity(0.7))
                }
            }
        }
    }
}
