import SwiftUI

struct SetScoreBadge: View {
    let mySetScore: Int
    let yourSetScore: Int

    var body: some View {
        if mySetScore > 0 || yourSetScore > 0 {
            HStack(spacing: 6) {
                Text("\(mySetScore)")
                    .foregroundColor(.green.opacity(0.8))
                Text("-")
                    .foregroundColor(.white.opacity(0.5))
                Text("\(yourSetScore)")
                    .foregroundColor(.orange.opacity(0.8))
            }
            .font(.system(size: 12, weight: .medium))
        }
    }
}
