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
            ScoreInfo(
                myGameScore: myGameScore,
                yourGameScore: yourGameScore,
                mySetScore: mySetScore,
                yourSetScore: yourSetScore,
                format: format
            )
            .padding(.top, 12)
            .allowsHitTesting(false)
            Spacer()
        }
        .allowsHitTesting(false)
        .overlay(alignment: .bottom) {
            if showUndo {
                UndoButton(action: onUndo)
                    .padding(.bottom, 20)
            }
        }
    }
}
