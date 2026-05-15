import SwiftUI

struct MatchResultView: View {
    let session: MatchSession
    @ObservedObject var viewModel: WorkoutSessionViewModel

    @State private var saved = false
    @State private var saveError: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Text(resultTitle)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(resultColor)

                HStack(spacing: 12) {
                    Text("\(session.mySetScore)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.green)
                    Text(":")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                    Text("\(session.yourSetScore)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.orange)
                }

                if session.options.mode == .bestOfThree, !session.completedSets.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(session.completedSets.enumerated()), id: \.offset) { index, set in
                            HStack(spacing: 2) {
                                Text("\(set.my):\(set.your)")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                                if index < session.completedSets.count - 1 {
                                    Text("|")
                                        .foregroundColor(.white.opacity(0.3))
                                        .padding(.horizontal, 4)
                                }
                            }
                        }
                    }
                }

                Spacer()

                HStack(spacing: 16) {
                    SaveButton(saved: saved) { saveMatch() }
                    RematchButton { viewModel.restartMatch() }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .navigationBarBackButtonHidden()
    }

    private var resultTitle: String {
        switch session.result {
        case .win:  String(localized: "watch_victory")
        case .loss: String(localized: "watch_defeat")
        case .draw: String(localized: "result_draw")
        case nil:   ""
        }
    }

    private var resultColor: Color {
        switch session.result {
        case .win:  .green
        case .loss: .orange
        case .draw: .yellow
        case nil:   .white
        }
    }

    private func saveMatch() {
        do {
            try viewModel.saveCurrentMatch()
            withAnimation { saved = true }
        } catch {
            saveError = error.localizedDescription
        }
    }
}

#Preview {
    let session = MatchSession(
        workoutSessionId: UUID(),
        options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false),
        kcalAtStart: 0
    )
    session.mySetScore = 2
    session.yourSetScore = 1
    session.completedSets = [SetScore(my: 6, your: 4), SetScore(my: 3, your: 6), SetScore(my: 6, your: 3)]
    session.result = .win

    return NavigationStack {
        MatchResultView(session: session, viewModel: WorkoutSessionViewModel())
    }
}
