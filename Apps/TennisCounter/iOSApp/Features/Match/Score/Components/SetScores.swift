import SwiftUI

struct SetScores: View {
    let mySetScore: Int
    let yourSetScore: Int

    var body: some View {
        if mySetScore > 0 || yourSetScore > 0 {
            HStack(spacing: 8) {
                Text("\(mySetScore)")
                    .foregroundColor(.green.opacity(0.85))
                Text(String(localized: "watch_set_label"))
                    .foregroundColor(.white.opacity(0.45))
                Text("\(yourSetScore)")
                    .foregroundColor(.orange.opacity(0.85))
            }
            .font(.system(size: 18, weight: .medium))
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        SetScores(mySetScore: 0, yourSetScore: 0)
        SetScores(mySetScore: 1, yourSetScore: 0)
        SetScores(mySetScore: 1, yourSetScore: 1)
    }
    .padding()
    .background(Color.black)
}
