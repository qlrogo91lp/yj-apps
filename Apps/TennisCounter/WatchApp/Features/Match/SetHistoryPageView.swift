import SwiftUI

struct SetHistoryPageView: View {
    let completedSets: [(my: Int, your: Int)]
    let myGameScore: Int
    let yourGameScore: Int

    var body: some View {
        VStack(spacing: 12) {
            Text("Sets")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))

            if completedSets.isEmpty {
                Text("No completed sets")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxHeight: .infinity)
            } else {
                ForEach(completedSets.indices, id: \.self) { idx in
                    let set = completedSets[idx]
                    HStack {
                        Text("Set \(idx + 1)")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                        Text("\(set.my)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.green)
                        Text("-")
                            .foregroundColor(.white.opacity(0.5))
                        Text("\(set.your)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal)
                }
            }

            Divider().background(Color.white.opacity(0.2))

            HStack {
                Text("Current")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text("\(myGameScore)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.green)
                Text("-")
                    .foregroundColor(.white.opacity(0.5))
                Text("\(yourGameScore)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.orange)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}
