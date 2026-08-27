import SwiftUI

struct MatchResultView: View {
    let session: MatchSession
    @ObservedObject var flowViewModel: WorkoutSessionViewModel

    var body: some View {
        VStack(spacing: 2) {
            Text(resultTitle)
                .font(.system(size: 25, weight: .bold))
                .foregroundColor(resultColor)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Text("\(session.mySetScore)")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundColor(.green)
                Text(":")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                Text("\(session.yourSetScore)")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundColor(.orange)
            }

            if session.options.mode == .bestOfThree, !session.completedSets.isEmpty {
                HStack {
                    ForEach(Array(session.completedSets.enumerated()), id: \.offset) { index, set in
                        HStack {
                            Text("\(set.my) : \(set.your)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                            if index < session.completedSets.count - 1 {
                                Text("|")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.horizontal, 4)
                            }
                        }
                    }
                }
            }

            Spacer()

            HStack(spacing: 6) {
                SaveButton(state: buttonState) { flowViewModel.saveCurrentMatch() }
                RematchButton { flowViewModel.restartMatch() }
            }
        }
        .padding(.horizontal, 8)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton { flowViewModel.startNewMatch() }
            }
        }
    }

    private var resultTitle: String {
        switch session.result {
        case .win: String(localized: "watch_victory")
        case .loss: String(localized: "watch_defeat")
        case .draw: String(localized: "result_draw")
        case nil: ""
        }
    }

    private var resultColor: Color {
        switch session.result {
        case .win: .green
        case .loss: .orange
        case .draw: .yellow
        case nil: .white
        }
    }

    private var buttonState: SaveButtonState {
        switch flowViewModel.saveAckState {
        case .idle: .idle
        case .pending: .pending
        case .succeeded: .saved
        case .failed: .failed
        }
    }
}

#Preview {
    let session = MatchSession(
        workoutSessionId: UUID(),
        options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false),
        kcalAtStart: 150
    )
    session.mySetScore = 1
    session.yourSetScore = 0
    session.completedSets = [SetScore(my: 6, your: 4), SetScore(my: 3, your: 6), SetScore(my: 3, your: 6)]
    session.endedAt = Date()
    session.result = .win
    session.kcalAtEnd = 200
    session.averageHeartRate = 145

    return MatchResultView(
        session: session,
        flowViewModel: WorkoutSessionViewModel()
    )
}
