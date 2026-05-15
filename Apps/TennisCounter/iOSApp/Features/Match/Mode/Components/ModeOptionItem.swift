import SwiftUI

struct ModeOptionItem: View {
    let format: MatchFormat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(format.localizedTitle)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.5))
            }
            Text(format.localizedDescription)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
