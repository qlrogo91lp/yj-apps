import SwiftUI

struct HomeView: View {
    let onMatchStart: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()

                VStack(spacing: 4) {
                    Text("Ralli")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.green)
                        .italic()
                    Text("Tennis Counter")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    onMatchStart()
                } label: {
                    Text(String(localized: "ios_start_workout"))
                        .font(.system(size: 18, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    HomeView(onMatchStart: {})
}
