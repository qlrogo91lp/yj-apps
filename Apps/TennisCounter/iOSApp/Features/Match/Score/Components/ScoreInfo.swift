import SwiftUI

struct ScoreInfo: View {
    let myGameScore: Int
    let yourGameScore: Int
    let mySetScore: Int
    let yourSetScore: Int
    let format: MatchFormat

    var body: some View {
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
}
