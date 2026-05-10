import SwiftUI

struct SetScores: View {
    let mySetScore: Int
    let yourSetScore: Int

    var body: some View {
        if mySetScore > 0 || yourSetScore > 0 {
            HStack(spacing: 6) {
                Text("\(mySetScore)")
                    .foregroundColor(.green.opacity(0.8))
                Text(String(localized: "watch_set_label"))
                    .foregroundColor(.white.opacity(0.5))
                Text("\(yourSetScore)")
                    .foregroundColor(.orange.opacity(0.8))
            }
            .font(.system(size: 16, weight: .medium))
        }
    }
}

#Preview {
    SetScores(mySetScore: 3, yourSetScore: 0)
}
