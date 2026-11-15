import SwiftUI

private enum Layout {
    static let numberSize: CGFloat = 20
    static let labelSize: CGFloat = 13
}

struct SetScores: View {
    let mySetScore: Int
    let yourSetScore: Int

    var body: some View {
        if mySetScore > 0 || yourSetScore > 0 {
            HStack(spacing: 4) {
                Text(verbatim: "\(mySetScore)")
                    .foregroundColor(.green.opacity(0.8))
                    .font(.system(size: Layout.numberSize, weight: .bold))
                Text(String(localized: "watch_set_label"))
                    .foregroundColor(.white.opacity(0.75))
                    .font(.system(size: Layout.labelSize, weight: .bold))
                Text(verbatim: "\(yourSetScore)")
                    .foregroundColor(.orange.opacity(0.8))
                    .font(.system(size: Layout.numberSize, weight: .bold))
            }
        }
    }
}

#Preview {
    SetScores(mySetScore: 3, yourSetScore: 0)
}
