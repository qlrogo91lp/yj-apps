import SwiftUI

struct RoundEndButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 20, weight: .semibold))
                Text("라운드 종료")
                    .font(.system(size: 13, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red.opacity(0.85))
    }
}
