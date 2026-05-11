import SwiftUI

struct ScoreOverlay: View {
    let myGameScore: Int
    let yourGameScore: Int
    let mySetScore: Int
    let yourSetScore: Int
    let format: MatchFormat
    let showUndo: Bool
    let onUndo: () -> Void

    var body: some View {
        VStack {
            scoreInfo
                .padding(.top, 12)
            Spacer()
            if showUndo {
                undoButton
                    .padding(.bottom, 20)
            }
        }
        .allowsHitTesting(false)
    }

    private var scoreInfo: some View {
        VStack(spacing: 4) {
            if format == .bestOfThree {
                HStack(spacing: 8) {
                    Text("\(mySetScore)")
                        .foregroundColor(.green)
                    Text("–")
                        .foregroundColor(.secondary)
                    Text("\(yourSetScore)")
                        .foregroundColor(.orange)
                }
                .font(.system(size: 16, weight: .bold))
            }
            HStack(spacing: 8) {
                Text("\(myGameScore)")
                    .foregroundColor(.green.opacity(0.7))
                Text("–")
                    .foregroundColor(.secondary)
                Text("\(yourGameScore)")
                    .foregroundColor(.orange.opacity(0.7))
            }
            .font(.system(size: 13, weight: .semibold))
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var undoButton: some View {
        Button(action: onUndo) {
            Label(String(localized: "btn_undo"), systemImage: "arrow.uturn.backward")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(.white.opacity(0.1), in: Capsule())
        }
        .allowsHitTesting(true)
    }
}
